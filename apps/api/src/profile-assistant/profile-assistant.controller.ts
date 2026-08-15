import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { CandidateAuthGuard } from '../auth/candidate-auth.guard';
import { CurrentCandidate } from '../auth/current-candidate.decorator';
import {
  ProfileAssistantRequestBody,
  ProfileAssistantService,
} from './profile-assistant.service';

@Controller('profile-assistant')
export class ProfileAssistantController {
  constructor(private readonly assistant: ProfileAssistantService) {}

  @Post('turn')
  @UseGuards(CandidateAuthGuard)
  async turn(
    @CurrentCandidate() candidateId: string,
    @Body() body: ProfileAssistantRequestBody,
  ) {
    return this.assistant.continueConversation(candidateId, body);
  }
}
