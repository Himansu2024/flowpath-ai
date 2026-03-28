# FlowPath AI — Deployment Guide

## Local Development (Docker)

```bash
# 1. Clone
git clone https://github.com/YOUR_ORG/flowpath-ai.git && cd flowpath-ai

# 2. Configure
cp backend/.env.example backend/.env
# Edit backend/.env — at minimum set JWT_SECRET

# 3. Start services
docker-compose -f docker/docker-compose.yml up -d

# 4. Run migrations
docker exec flowpath-backend node -e "
  const { connectDatabase } = require('./src/config/database');
  connectDatabase();
"

# 5. Seed Bengaluru signals
docker exec flowpath-db psql -U flowpath_user -d flowpath_db \
  -f /docker-entrypoint-initdb.d/bangalore_signals.sql

# 6. Verify
curl http://localhost:3000/health        # Backend API
curl http://localhost:8000/health        # AI Engine
open http://localhost:3001               # Admin dashboard
```

---

## AWS Production Deployment

### Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform 1.5+ installed
- Docker installed
- SSH key pair for EC2

### Step 1: Create Terraform state bucket
```bash
aws s3 mb s3://flowpath-terraform-state --region ap-south-1
aws s3api put-bucket-versioning --bucket flowpath-terraform-state \
  --versioning-configuration Status=Enabled
aws dynamodb create-table --table-name flowpath-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region ap-south-1
```

### Step 2: Create ECR repositories
```bash
aws ecr create-repository --repository-name flowpath-backend --region ap-south-1
aws ecr create-repository --repository-name flowpath-ai --region ap-south-1
```

### Step 3: Terraform apply
```bash
cd infrastructure/terraform
terraform init
terraform apply \
  -var="key_pair_name=flowpath-key" \
  -var="public_key_path=~/.ssh/flowpath.pub" \
  -var="db_username=flowpath_admin" \
  -var="db_password=YourSecurePassword123!" \
  -var="admin_ip=$(curl -s ifconfig.me)/32" \
  -var="github_org=YOUR_GITHUB_ORG"
```

### Step 4: Configure GitHub Actions secrets
In your GitHub repo → Settings → Secrets and variables → Actions:

| Secret                  | Value                          |
|-------------------------|--------------------------------|
| `AWS_ACCESS_KEY_ID`     | IAM user access key            |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key            |
| `ECR_REGISTRY`          | Your ECR registry URL          |
| `EC2_HOST`              | EC2 public IP                  |
| `EC2_SSH_KEY`           | Contents of your .pem file     |
| `DB_HOST`               | RDS endpoint                   |
| `DB_USER`               | flowpath_admin                 |
| `DB_PASSWORD`           | Your DB password               |
| `JWT_SECRET`            | Strong random secret           |
| `AI_ENGINE_API_KEY`     | Secure API key                 |
| `CLOUDFRONT_DOMAIN`     | CloudFront domain name         |

### Step 5: Push to trigger CI/CD
```bash
git push origin main
```
This triggers: Test → Build → Push ECR → Migrate DB → Deploy → Health Check

---

## Flutter Mobile App Build

### Android Debug
```bash
cd mobile/flowpath_app
flutter pub get
flutter run                          # Run on connected device
```

### Android Release APK
```bash
flutter build apk --release --dart-define=API_URL=https://YOUR_CLOUDFRONT_DOMAIN/api/v1
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (Google Play)
```bash
# 1. Create keystore (one time only)
keytool -genkey -v \
  -keystore android/flowpath-release.jks \
  -keyAlias flowpath \
  -keyalg RSA -keysize 2048 \
  -validity 10000

# 2. Create android/key.properties
cat > android/key.properties << KEYEOF
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=flowpath
storeFile=../flowpath-release.jks
KEYEOF

# 3. Build AAB
flutter build appbundle --release \
  --dart-define=API_URL=https://YOUR_CLOUDFRONT_DOMAIN/api/v1

# Output: build/app/outputs/bundle/release/app-release.aab
```

### Google Play Console Upload
1. Go to https://play.google.com/console
2. Create app → Set up your app
3. Production → Create new release → Upload AAB
4. Fill store listing:
   - **Title**: FlowPath AI — Traffic Navigator
   - **Short description**: Navigate smarter. Beat every red light.
   - **Full description**: FlowPath AI uses GreenWave technology to predict traffic signal timing and recommend the perfect speed to pass through intersections on green — reducing stops, saving fuel, and cutting your commute time.
   - **Screenshots**: 4+ phone screenshots, 1 feature graphic (1024x500)
   - **Category**: Maps & Navigation
   - **Content rating**: Complete questionnaire
5. App content → Permissions: explain location usage
6. Submit for review (typically 1–3 business days)

---

## Environment Variables Reference

| Variable              | Required | Default   | Description                     |
|-----------------------|----------|-----------|---------------------------------|
| `NODE_ENV`            | ✅       | development | Runtime environment           |
| `PORT`                | ✅       | 3000      | HTTP server port                |
| `DB_HOST`             | ✅       | localhost | PostgreSQL hostname             |
| `DB_PORT`             | ✅       | 5432      | PostgreSQL port                 |
| `DB_NAME`             | ✅       | flowpath_db | Database name                 |
| `DB_USER`             | ✅       | flowpath_user | DB username                 |
| `DB_PASSWORD`         | ✅       | —         | DB password                     |
| `REDIS_URL`           | ✅       | redis://localhost:6379 | Redis URL      |
| `JWT_SECRET`          | ✅       | —         | Min 32 character secret         |
| `JWT_EXPIRES_IN`      | ⬜       | 7d        | Token expiry                    |
| `AI_ENGINE_URL`       | ✅       | http://localhost:8000 | AI service URL |
| `AI_ENGINE_API_KEY`   | ✅       | dev-key   | AI service auth key             |
| `AWS_REGION`          | ⬜       | ap-south-1 | AWS region                    |
| `AWS_ACCESS_KEY_ID`   | ⬜       | —         | AWS access key                  |
| `AWS_SECRET_ACCESS_KEY` | ⬜     | —         | AWS secret key                  |
| `AWS_S3_BUCKET`       | ⬜       | —         | S3 bucket name                  |
| `RATE_LIMIT_MAX_REQUESTS` | ⬜   | 200       | Requests per 15 minutes         |
| `LOG_LEVEL`           | ⬜       | info      | winston log level               |

