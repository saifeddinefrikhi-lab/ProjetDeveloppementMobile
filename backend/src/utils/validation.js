import Joi from 'joi';

export const registerSchema = Joi.object({
  name: Joi.string().trim().min(2).max(100).required(),
  email: Joi.string().trim().lowercase().email().max(255).required(),
  password: Joi.string().min(8).max(128).required(),
});
export const loginSchema = Joi.object({ email: Joi.string().trim().lowercase().email().required(), password: Joi.string().required() });
export const forgotPasswordSchema = Joi.object({ email: Joi.string().trim().lowercase().email().required() });
export const verifyResetCodeSchema = Joi.object({
  email: Joi.string().trim().lowercase().email().required(),
  code: Joi.string().pattern(/^\d{6}$/).required(),
});
export const resetPasswordSchema = Joi.object({
  token: Joi.string().pattern(/^\d{6}$/).required(),
  newPassword: Joi.string().min(8).max(128).required(),
});
export const profileSchema = Joi.object({
  name: Joi.string().trim().min(2).max(100),
  avatarInitials: Joi.string().trim().max(10).allow('', null),
  avatarUrl: Joi.string().uri().max(1000).allow('', null),
  currentPassword: Joi.string().max(128),
  newPassword: Joi.string().min(8).max(128),
}).min(1);
export const collectionSchema = Joi.object({
  address: Joi.string().trim().min(3).max(500).required(),
  latitude: Joi.number().min(-90).max(90),
  longitude: Joi.number().min(-180).max(180),
  location: Joi.object({ type: Joi.valid('Point').required(), coordinates: Joi.array().length(2).items(Joi.number()).required() }),
  wasteTypes: Joi.array().items(Joi.string().trim().min(1).max(50)).min(1).max(20).required(),
  notes: Joi.string().trim().max(2000).allow('', null),
  requestedDate: Joi.date().iso().required(),
}).custom((value, helpers) => {
  const hasCoordinates = value.latitude !== undefined && value.longitude !== undefined;
  if (!hasCoordinates && !value.location) return helpers.error('any.custom', { message: 'latitude/longitude or location is required' });
  return value;
});
export const statusSchema = Joi.object({ status: Joi.string().valid('completed', 'cancelled').required() });
export const scanSchema = Joi.object({
  imageUrl: Joi.string().uri().max(1000),
  categoryId: Joi.string().trim().max(50).required(),
  modelLabel: Joi.string().trim().max(100).required(),
  confidence: Joi.number().min(0).max(1).required(),
  scannedAt: Joi.date().iso().default(() => new Date()),
});
export const eventSchema = Joi.object({
  title: Joi.string().trim().min(3).max(180).required(),
  description: Joi.string().trim().min(3).max(5000).required(),
  eventType: Joi.string().valid('cleanup', 'tree_planting', 'recycling_workshop', 'other').required(),
  location: Joi.string().trim().min(3).max(500).required(),
  latitude: Joi.number().min(-90).max(90).required(),
  longitude: Joi.number().min(-180).max(180).required(),
  startsAt: Joi.date().iso().required(),
  endsAt: Joi.date().iso().greater(Joi.ref('startsAt')).required(),
  capacity: Joi.number().integer().min(1).max(100000).required(),
});
export const eventStatusSchema = Joi.object({ status: Joi.string().valid('planned', 'completed', 'cancelled').required() });
export const attendanceSchema = Joi.object({ attended: Joi.boolean().required() });

export function validate(schema, payload) {
  const { value, error } = schema.validate(payload, { abortEarly: false, stripUnknown: true });
  if (error) {
    const err = new Error('Validation failed');
    err.status = 422;
    err.details = error.details.map((item) => item.message);
    throw err;
  }
  return value;
}
