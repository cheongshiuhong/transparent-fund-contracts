// Types
import { ContractsState } from "../interfaces";

// Code
import setupCore from "./core";
import setupProtocols from "./protocols";

/** Setup the dependencies on the chain */
export default async (state: ContractsState): Promise<ContractsState> => {
    console.log("--- bsc > setup > start ---");
    const output = await setupCore(state).then(setupProtocols);
    console.log("--- bsc > setup > done ---");

    return output;
};
