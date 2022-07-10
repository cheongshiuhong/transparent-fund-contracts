// Types
import type { ContractsState } from "../../interfaces";

// Code
import setupPancakeswap from "./pancakeswap";
import setupVenus from "./venus";

export default async (state: ContractsState): Promise<ContractsState> => setupPancakeswap(state).then(setupVenus);
