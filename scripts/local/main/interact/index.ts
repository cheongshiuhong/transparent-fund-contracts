// Types
import { ContractsState } from "../interfaces";

// Code
// import interactSuite1 from "./suite1";
import interactSuite2 from "./suite2";

/** Deploy our contracts */
export default async (state: ContractsState): Promise<ContractsState> => {
    console.log("--- bsc > interact > start ---");

    // await interactSuite1(state, true);
    await interactSuite2(state, true);

    console.log("--- bsc > interact > done ---");

    return state;
};
