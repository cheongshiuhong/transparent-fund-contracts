// Types
import type { ContractsState } from "../interfaces";

// Libraries
import fs from "fs";
import yaml from "js-yaml";

/** Output the details into a yaml file */
export default async (state: ContractsState): Promise<ContractsState> => {
    if (!state.mainFund) return state;
    if (!state.tokens) return state;

    console.log("--- bsc > output > start ---");

    const output = {
        fund: {
            fund: state.mainFund.fund.address,
            roles: {
                holders: state.mainFund.roles.holders.map((each) => each.address),
                managers: state.mainFund.roles.managers.map((each) => each.address),
                operators: state.mainFund.roles.operators.map((each) => each.address),
                taskRunner: state.mainFund.roles.taskRunner.address,
            },
            opsGovernor: state.mainFund.opsGovernor.address,
            fundToken: state.mainFund.fundToken.address,
            cao: state.mainFund.cao.address,
            caoToken: state.mainFund.caoToken.address,
            humanResources: state.mainFund.humanResources.address,
            accounting: state.mainFund.accounting.address,
            frontOffice: state.mainFund.frontOffice.address,
            incentivesManager: state.mainFund.incentivesManager.address,
            incentives: Object.entries(state.mainFund.incentives).reduce(
                (current, [key, value]) => ({ ...current, [key]: value.address }),
                {}
            ),
        },
    };

    // Write json file
    fs.writeFileSync("bsc-config-local.json", JSON.stringify(output, null, 2));

    // Write yaml file
    fs.writeFileSync("bsc-config-local.yaml", yaml.dump(output));

    console.log("--- bsc > output > done ---");

    return state;
};
