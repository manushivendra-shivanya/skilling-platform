import { randomUUID } from 'crypto';
import { NextFunction, Request, Response } from 'express';

export interface RequestWithId extends Request {
  requestId: string;
}

export class RequestIdMiddleware {
  use = (req: RequestWithId, res: Response, next: NextFunction) => {
    req.requestId = `req_${randomUUID()}`;
    res.setHeader('x-request-id', req.requestId);
    next();
  };
}
