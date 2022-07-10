// Types
import type { ContractsState } from "../../interfaces";

// Code
import setupTokens from "./tokens";

export default async (state: ContractsState): Promise<ContractsState> => setupTokens(state);
