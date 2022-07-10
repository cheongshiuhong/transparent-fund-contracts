// Types
import type { ContractsState } from "../../interfaces";

// Code
import interactPancakeswap from "./pancakeswap";
import interactVenus from "./venus";

/** Interact with the protocols through the fund */
export default async (state: ContractsState): Promise<ContractsState> => {
    if (!state.baseFund) return state;

    console.log("--- bsc > interact > protocols > start ---");

    await interactPancakeswap(state);
    await interactVenus(state);

    console.log("--- bsc > interact > protocols > done ---");

    return state;
};
