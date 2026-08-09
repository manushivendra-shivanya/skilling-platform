// Plain JS shim, deliberately: `nest build` (this project's Build Command
// on Vercel) already compiles `src/serverless.ts` to `dist/serverless.js`
// with the correct NestJS decorator/DI setup -- this file just re-exports
// that compiled handler as the one function Vercel discovers under /api,
// with `vercel.json`'s catch-all rewrite routing every request here.
module.exports = require('../dist/serverless.js').default;
