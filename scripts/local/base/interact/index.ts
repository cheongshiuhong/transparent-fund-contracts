// Types
import type { ContractsState } from "../interfaces";

// Code
import interactProtocols from "./protocols";
import interactUtils from "./utils";

/** Interact with the protocols through the fund */
export default async (state: ContractsState): Promise<ContractsState> => {
    if (!state.baseFund) return state;

    console.log("--- bsc > interact > start ---");

    await interactProtocols(state);
    await interactUtils(state);

    console.log("--- bsc > interact > done ---");

    return state;
};
