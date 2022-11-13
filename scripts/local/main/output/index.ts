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

    const tokens: Record<string, string[]> = state.tokens.reduce(
        (current, each, index) => ({
            ...current,
            [index === 0 ? "WETH" : `TKN${index}`]: [each.token.address, each.chainlinkOracle.address],
        }),
        {}
    );

    const output = {
        tokens: Object.entries(tokens).reduce(
            (current, [symbol, [address, oracle]]) => ({
                ...current,
                [symbol]: { address, decimals: 18, oracle },
            }),
            {}
        ),
        fund: {
            roles: {
                holders: state.mainFund.roles.holders.map((each) => each.address),
                managers: state.mainFund.roles.managers.map((each) => each.address),
                operators: state.mainFund.roles.operators.map((each) => each.address),
                taskRunner: state.mainFund.roles.taskRunner.address,
            },
            cao: state.mainFund.cao.address,
            caoToken: state.mainFund.caoToken.address,
            caoParameters: state.mainFund.caoParameters.address,
            humanResources: state.mainFund.humanResources.address,
            fund: state.mainFund.fund.address,
            opsGovernor: state.mainFund.opsGovernor.address,
            fundToken: state.mainFund.fundToken.address,
            accounting: state.mainFund.accounting.address,
            frontOffice: state.mainFund.frontOffice.address,
            frontOfficeParameters: state.mainFund.frontOfficeParameters.address,
            incentivesManager: state.mainFund.incentivesManager.address,
            incentives: Object.entries(state.mainFund.incentives).reduce(
                (current, [key, value]) => ({ ...current, [key]: value.address }),
                {}
            ),
        },
    };

    const dir = "outputs/local-main/";

    !fs.existsSync(dir) && fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(dir + "addresses.yaml", yaml.dump(output));

    console.log("--- bsc > output > done ---");

    return state;
};
