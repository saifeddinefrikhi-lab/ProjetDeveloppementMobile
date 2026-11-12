import 'dotenv/config';

const requiredInProduction = ['JWT_SECRET'];
if (process.env.NODE_ENV === 'production') {
  const missing = requiredInProduction.filter((key) => !process.env[key]);
  if (missing.length) throw new Error(`Missing environment variables: ${missing.join(', ')}`);
}

export const env = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: Number(process.env.PORT || 3000),
  corsOrigin: process.env.CORS_ORIGIN || '*',
  jwtSecret: process.env.JWT_SECRET || 'development-only-change-me',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '7d',
  dbPath: process.env.SQLITE_DB_PATH || 'data/waste_classification.sqlite',
  uploadDir: process.env.UPLOAD_DIR || 'uploads',
  maxFileSizeMb: Number(process.env.MAX_FILE_SIZE_MB || 10),
  aiClassifierProvider: process.env.AI_CLASSIFIER_PROVIDER || 'groq',
  groq: {
    apiKey: process.env.GROQ_API_KEY || '',
    model: process.env.GROQ_MODEL || 'qwen/qwen3.8-27b',
  },
  mlServiceUrl: process.env.ML_SERVICE_URL || 'http://127.0.0.1:8000/predict',
  mlServiceLogUrl: process.env.ML_SERVICE_LOG_URL || 'http://127.0.0.1:8000/classification-log',
  mlServiceTimeoutMs: Number(process.env.ML_SERVICE_TIMEOUT_MS || 60000),
  publicBaseUrl: process.env.PUBLIC_BASE_URL || 'http://localhost:3000',
  passwordResetUrl: process.env.PASSWORD_RESET_URL || 'http://localhost:3000/reset-password',
  emailProvider: process.env.EMAIL_PROVIDER || 'gmail',
  gmail: {
    clientId: process.env.GMAIL_CLIENT_ID || '',
    clientSecret: process.env.GMAIL_CLIENT_SECRET || '',
    refreshToken: process.env.GMAIL_REFRESH_TOKEN || '',
    from: process.env.GMAIL_FROM || '',
  },
  smtp: {
    host: process.env.SMTP_HOST || '',
    port: Number(process.env.SMTP_PORT || 587),
    secure: process.env.SMTP_SECURE === 'true',
    user: process.env.SMTP_USER || '',
    password: process.env.SMTP_PASSWORD || '',
    from: process.env.SMTP_FROM || '',
  },
};
