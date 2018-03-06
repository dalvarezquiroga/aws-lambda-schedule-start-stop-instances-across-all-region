resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "lambda_iam_role_policy" {
  name = "lambda_iam_role_policy"
  role = "${aws_iam_role.iam_for_lambda.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": "ec2:*",
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOF
}

data "archive_file" "cost_savings_zip" {
  type        = "zip"
  source_file = "lambda/cost_savings.py"
  output_path = "lambda/cost_savings.zip"
}

resource "aws_s3_bucket_object" "lambda_cost_savings" {
  bucket  = "${aws_s3_bucket.config.bucket}"
  key     = "lambda/cost_savings.zip"
  content = "${data.archive_file.cost_savings_zip.output_path}"

  tags {
    Name    = "${var.project_name}"
    project = "${var.project_name}"
  }
}

resource "aws_lambda_function" "cost_saving_start_lambda" {
  filename         = "${data.archive_file.cost_savings_zip.output_path}"
  function_name    = "start_costs_savings"
  role             = "${aws_iam_role.iam_for_lambda.arn}"
  handler          = "cost_savings.start_lambda_handler"
  runtime          = "python2.7"
  timeout          = "300"
  source_code_hash = "${base64sha256(file("lambda/cost_savings.zip"))}"
}

resource "aws_lambda_function" "cost_saving_stop_lambda" {
  filename         = "${data.archive_file.cost_savings_zip.output_path}"
  function_name    = "stop_costs_savings"
  role             = "${aws_iam_role.iam_for_lambda.arn}"
  handler          = "cost_savings.stop_lambda_handler"
  runtime          = "python2.7"
  timeout          = "300"
  source_code_hash = "${base64sha256(file("lambda/cost_savings.zip"))}"
}

resource "aws_cloudwatch_event_rule" "at_morning" {
  name                = "at_morning"
  description         = "Fires when the day starts"
  schedule_expression = "cron(10 5 * * ? *)"
}

resource "aws_cloudwatch_event_rule" "at_night" {
  name                = "at_night"
  description         = "Fires when the day ends"
  schedule_expression = "cron(10 20 * * ? *)"
}

resource "aws_cloudwatch_event_target" "cost_saving_on_morning" {
  rule      = "${aws_cloudwatch_event_rule.at_morning.name}"
  target_id = "cost_saving_morning"
  arn       = "${aws_lambda_function.cost_saving_start_lambda.arn}"
}

resource "aws_cloudwatch_event_target" "cost_saving_on_night" {
  rule      = "${aws_cloudwatch_event_rule.at_night.name}"
  target_id = "cost_saving_night"
  arn       = "${aws_lambda_function.cost_saving_stop_lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_start_instances" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.cost_saving_start_lambda.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.at_morning.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_stop_instances" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.cost_saving_stop_lambda.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.at_night.arn}"
}
