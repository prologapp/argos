import { render } from "react-email";
import { Resend } from "resend";

import config from "@/config";
import logger from "@/logger";

const production = config.get("env") === "production";
const resendApiKey = config.get("resend.apiKey");

// Resend throws if the API key is missing, so we only instantiate it when a key
// is provided. Email sending is optional: without a key (e.g. self-hosted
// setups) emails are simply skipped instead of crashing the app.
const resend = resendApiKey ? new Resend(resendApiKey) : null;

const defaultFrom = config.get("email.from");

/**
 * Send an email using Resend.
 */
export async function sendEmail(options: {
  /**
   * Email address to send to.
   */
  to: string[];
  /**
   * Email subject.
   */
  subject: string;
  /**
   * Email body as React element.
   */
  react: React.ReactElement;
}) {
  if (!resend) {
    if (production) {
      logger.warn("Resend API key is missing, skipping email sending");
    }
    return null;
  }
  const text = await render(options.react, { plainText: true });
  return resend.emails.send({ ...options, text, from: defaultFrom });
}
