import nodemailer from 'nodemailer';
import { google } from 'googleapis';
import { env } from '../config/env.js';

let transporter;
let gmailClient;

function getSmtpTransporter() {
  if (!env.smtp.host || !env.smtp.from) {
    const error = new Error('Password reset email is not configured');
    error.status = 503;
    throw error;
  }
  transporter ??= nodemailer.createTransport({
    host: env.smtp.host,
    port: env.smtp.port,
    secure: env.smtp.secure,
    auth: env.smtp.user ? { user: env.smtp.user, pass: env.smtp.password } : undefined,
  });
  return transporter;
}

function getGmailClient() {
  const { clientId, clientSecret, refreshToken, from } = env.gmail;
  if (!clientId || !clientSecret || !refreshToken || !from) {
    const error = new Error('Gmail API password reset email is not configured');
    error.status = 503;
    throw error;
  }
  if (!gmailClient) {
    const auth = new google.auth.OAuth2(clientId, clientSecret);
    auth.setCredentials({ refresh_token: refreshToken });
    gmailClient = google.gmail({ version: 'v1', auth });
  }
  return gmailClient;
}

function encodedMessage({ to, subject, text, html, from }) {
  const boundary = `=_reset_${Date.now().toString(36)}`;
  const message = [
    `From: ${from}`,
    `To: ${to}`,
    `Subject: ${subject}`,
    'MIME-Version: 1.0',
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
    '',
    `--${boundary}`,
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: 8bit',
    '',
    text,
    `--${boundary}`,
    'Content-Type: text/html; charset=UTF-8',
    'Content-Transfer-Encoding: 8bit',
    '',
    html,
    `--${boundary}--`,
  ].join('\r\n');
  return Buffer.from(message)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

export async function sendPasswordResetEmail(email, token) {
  const subject = 'Your Waste Classification password reset code';
  const text = `Your password reset code is: ${token}\n\nThis code expires in one hour and can only be used once.`;
  const html = `<p>Your password reset code is:</p><p style="font-size: 28px; font-weight: bold; letter-spacing: 6px">${token}</p><p>This code expires in one hour and can only be used once.</p>`;
  if (env.emailProvider === 'smtp') {
    await getSmtpTransporter().sendMail({ from: env.smtp.from, to: email, subject, text, html });
    return;
  }
  if (env.emailProvider !== 'gmail') {
    const error = new Error(`Unsupported email provider: ${env.emailProvider}`);
    error.status = 500;
    throw error;
  }
  try {
    await getGmailClient().users.messages.send({
      userId: 'me',
      requestBody: {
        raw: encodedMessage({ to: email, subject, text, html, from: env.gmail.from }),
      },
    });
  } catch (error) {
    const gmailError = error?.response?.data?.error;
    if (gmailError === 'invalid_grant') {
      const configurationError = new Error(
        'Gmail OAuth refresh token is invalid or revoked. Generate a new refresh token for the configured OAuth client.',
      );
      configurationError.status = 503;
      throw configurationError;
    }
    throw error;
  }
}
