// Types
import type { ContractsState } from "../../interfaces";

// Code
import setupTokens from "./tokens";
import setupMulticall from "./multicall";

export default async (state: ContractsState): Promise<ContractsState> => setupTokens(state).then(setupMulticall);
