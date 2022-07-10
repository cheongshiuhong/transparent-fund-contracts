// Types
import { ContractsState } from "../interfaces";

// Code
import deployBaseFund from "./fund";

/** Deploy our contracts */
export default async (state: ContractsState): Promise<ContractsState> => {
    console.log("--- bsc > deploy > start ---");
    const output = await deployBaseFund(state);
    console.log("--- bsc > deploy > done ---");

    return output;
};
