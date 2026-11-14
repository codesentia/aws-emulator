# AWS Emulator Setup & Usage

AWS Emulator (`v1.0.342`) is configured to run locally on `https://127.0.0.1:9297`.

---

## 1. What Was Run & Verified

1. **Checked installed binary**:
   ```bash
   /opt/aws-emulator/bin/aws-emulator -v
   # Version: 1.0.342 (Release date: 2026.11.13)
   ```

2. **Created the connection environment file** at `~/.aws/emulator/9297.env`:
   ```bash
   export AWS_ENDPOINT_URL=https://127.0.0.1:9297
   export AWS_SHARED_CREDENTIALS_FILE=$HOME/.aws/emulator/9297/emulator_credentials
   export AWS_CONFIG_FILE=$HOME/.aws/emulator/9297/config
   export AWS_EC2_METADATA_DISABLED=true   # never fall back to EC2 instance credentials
   export AWS_REGION=us-east-1
   export AWS_DEFAULT_REGION=us-east-1

   # Environment credentials win over the credentials file: real keys would be sent and rejected.
   unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE AWS_DEFAULT_PROFILE \
     AWS_WEB_IDENTITY_TOKEN_FILE AWS_ROLE_ARN AWS_ROLE_SESSION_NAME AWS_CONTAINER_CREDENTIALS_RELATIVE_URI \
     AWS_CONTAINER_CREDENTIALS_FULL_URI AWS_CONTAINER_AUTHORIZATION_TOKEN

   # Emulator in Docker (always on macOS and Windows): config's ca_bundle is a container path.
   export AWS_CA_BUNDLE=$HOME/.aws/emulator/9297/ca.pem

   export AWS_PAGER=""                      # optional: CLI output inline instead of through a pager
   ```

3. **Started the emulator in the background**:
   ```bash
   mkdir -p ~/.aws/emulator
   nohup /opt/aws-emulator/bin/aws-emulator -p 9297 > ~/.aws/emulator/9297.log 2>&1 &
   ```

4. **Verified health check & identity**:
   ```bash
   curl --cacert ~/.aws/emulator/9297/ca.pem https://127.0.0.1:9297/__admin/health
   # ok

   ( . ~/.aws/emulator/9297.env && aws sts get-caller-identity )
   # {
   #     "UserId": "AIDAH5I7GEMO7ADXNFAZU",
   #     "Account": "000000000000",
   #     "Arn": "arn:aws:iam::000000000000:user/emulator"
   # }
   ```

---

## 2. How to Point Your Project / Shell at the Emulator

- **Per-command or test script (recommended)**:
  Source `~/.aws/emulator/9297.env` inside a subshell or at the top of your test script so it does not overwrite real AWS credentials in your main shell:
  ```bash
  ( . ~/.aws/emulator/9297.env && <your-command-or-tests> )
  ```
- **Interactive shell**:
  Run `source ~/.aws/emulator/9297.env` (open a new shell when you want to return to your normal AWS profile).
- **SDK TLS Trust**:
  - **AWS CLI v2, Python (`boto3`), Go v2**: Work out of the box with `~/.aws/emulator/9297.env` (no code changes needed, e.g., `boto3.client("s3").list_buckets()`).
  - **Node.js (AWS SDK for JS v3)**: Also set `export NODE_EXTRA_CA_CERTS=$HOME/.aws/emulator/9297/ca.pem`.
  - **Rust / .NET**: Also set `export SSL_CERT_FILE=$HOME/.aws/emulator/9297/ca.pem`.
- **Important**: Never commit `~/.aws/emulator/9297/config`, `emulator_credentials`, or `ca.pem`—they are regenerated on every start.

---

## 3. Telemetry Notice

- **Telemetry is enabled by default** when starting `aws-emulator`.
- To disable telemetry, pass `-t off` when starting the emulator (or set `EMULATOR_TELEMETRY=off`, or `-e EMULATOR_TELEMETRY=off` in Docker). In CI jobs and agent sandboxes, always start it with `-t off`.
- For details on what telemetry collects, see the [AWS Emulator User Guide](https://docs.aws.amazon.com/emulator/latest/userguide/).
