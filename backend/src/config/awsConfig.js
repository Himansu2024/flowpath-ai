// backend/src/config/awsConfig.js
// AWS SDK configuration for S3, Lambda, CloudFront

const AWS = require('aws-sdk');

// Configure AWS SDK with credentials from environment
AWS.config.update({
  region: process.env.AWS_REGION || 'ap-south-1',
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
});

// S3 client for asset storage (map tiles, user uploads)
const s3 = new AWS.S3({
  params: { Bucket: process.env.AWS_S3_BUCKET },
});

// Lambda client for invoking AI prediction tasks
const lambda = new AWS.Lambda();

// CloudWatch for centralized logging
const cloudWatch = new AWS.CloudWatch();

/**
 * Upload file to S3.
 * @param {string} key - S3 object key (file path)
 * @param {Buffer} body - File content
 * @param {string} contentType - MIME type
 * @returns {Promise<string>} Public URL of uploaded file
 */
const uploadToS3 = async (key, body, contentType = 'application/octet-stream') => {
  const params = {
    Bucket: process.env.AWS_S3_BUCKET,
    Key: key,
    Body: body,
    ContentType: contentType,
    ACL: 'public-read',
  };
  const result = await s3.upload(params).promise();
  return result.Location;
};

/**
 * Invoke Lambda function for heavy AI processing tasks.
 * @param {string} functionName - Lambda function ARN or name
 * @param {Object} payload - Input data for Lambda
 * @returns {Promise<Object>} Lambda response
 */
const invokeLambda = async (functionName, payload) => {
  const params = {
    FunctionName: functionName,
    InvocationType: 'RequestResponse',
    Payload: JSON.stringify(payload),
  };
  const result = await lambda.invoke(params).promise();
  return JSON.parse(result.Payload);
};

module.exports = { s3, lambda, cloudWatch, uploadToS3, invokeLambda };
