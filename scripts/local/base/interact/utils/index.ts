// Types
import type { ContractsState } from "../../interfaces";

// Code
import interactPancakeswapLpFarmingUtil from "./pancakeswapLpFarmingUtil";

/** Interact with the utils through the fund */
export default async (state: ContractsState): Promise<ContractsState> => {
    if (!state.baseFund) return state;

    console.log("--- bsc > interact > utils > start ---");

    await interactPancakeswapLpFarmingUtil(state);

    console.log("--- bsc > interact > utils > done ---");

    return state;
};
