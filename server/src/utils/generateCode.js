const User = require('../models/User');

const generateUniqueCode = async () => {
  const chars = '0123456789ABCDEF';
  let code;
  let exists = true;

  while (exists) {
    code = 'MS-';
    for (let i = 0; i < 4; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    const existing = await User.findOne({ uniqueCode: code });
    exists = !!existing;
  }

  return code;
};

module.exports = generateUniqueCode;
