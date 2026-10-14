import mongoose from 'mongoose';
const profileSchema = new mongoose.Schema({
  user: {type: mongoose.Schema.Types.ObjectId, ref: 'User', unique: true, required: true},
  type: {type: String, enum: ['STARTUP', 'INVESTOR'], required: true},
  name: {type: String, required: true, trim: true, maxlength: 100},
  location: {type: String, maxlength: 120},
  industry: {type: String, maxlength: 120},
  businessStage: {type: String, maxlength: 120},
  description: {type: String, maxlength: 2000},
  website: {type: String, maxlength: 500},
  fundingRequired: Number,
  fundingRaised: Number,
  investmentRangeMin: Number,
  investmentRangeMax: Number,
  preferences: [String],
  pitch: {
    url: String,
    filename: String,
    title: String,
    summary: String,
    description: String,
    size: Number,
    updatedAt: Date,
  },
}, {timestamps: true});
profileSchema.index({type: 1, industry: 1, location: 1, businessStage: 1});
export default mongoose.model('Profile', profileSchema);
