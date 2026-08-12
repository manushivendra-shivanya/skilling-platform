import { Body, Controller, Delete, Get, Param, Post, Put, UseGuards } from '@nestjs/common';
import { CandidateAuthGuard } from '../auth/candidate-auth.guard';
import { CurrentCandidate } from '../auth/current-candidate.decorator';
import { NetworkingService, PublishProfileBody } from './networking.service';

@Controller('networking')
@UseGuards(CandidateAuthGuard)
export class NetworkingController {
  constructor(private readonly networking: NetworkingService) {}

  @Put('profile')
  async publishProfile(
    @CurrentCandidate() candidateId: string,
    @Body() body: PublishProfileBody,
  ) {
    return this.networking.publishProfile(candidateId, body);
  }

  @Get('discover')
  async discover(@CurrentCandidate() candidateId: string) {
    return { candidates: await this.networking.discover(candidateId) };
  }

  @Post('connections')
  async sendConnectionRequest(
    @CurrentCandidate() candidateId: string,
    @Body('recipientCandidateId') recipientCandidateId: string,
  ) {
    return this.networking.sendConnectionRequest(candidateId, recipientCandidateId);
  }

  @Get('connections')
  async listConnections(@CurrentCandidate() candidateId: string) {
    return this.networking.listConnections(candidateId);
  }

  @Post('connections/:id/respond')
  async respondToConnection(
    @CurrentCandidate() candidateId: string,
    @Param('id') connectionId: string,
    @Body('accept') accept: boolean,
  ) {
    return this.networking.respondToConnection(candidateId, connectionId, accept === true);
  }

  @Post('connections/:id/withdraw')
  async withdrawConnection(
    @CurrentCandidate() candidateId: string,
    @Param('id') connectionId: string,
  ) {
    return this.networking.withdrawConnection(candidateId, connectionId);
  }

  @Post('blocks')
  async blockCandidate(
    @CurrentCandidate() candidateId: string,
    @Body('candidateId') blockedId: string,
  ) {
    await this.networking.blockCandidate(candidateId, blockedId);
    return { blocked: true };
  }

  @Delete('blocks/:candidateId')
  async unblockCandidate(
    @CurrentCandidate() candidateId: string,
    @Param('candidateId') blockedId: string,
  ) {
    await this.networking.unblockCandidate(candidateId, blockedId);
    return { blocked: false };
  }
}
