// Types
import { ContractsState } from "../interfaces";

// Code
import setupCore from "./core";

/** Setup the dependencies on the chain */
export default async (state: ContractsState): Promise<ContractsState> => {
    console.log("--- bsc > setup > start ---");
    const output = await setupCore(state);
    console.log("--- bsc > setup > done ---");

    return output;
};
