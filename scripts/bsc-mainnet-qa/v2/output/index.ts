// Types
import type { DeploymentState } from "../interfaces";

// Libraries
import fs from "fs";
import yaml from "js-yaml";

export default async (state: DeploymentState): Promise<DeploymentState> => {
    const addressesOutput = {
        cao: state.contracts.CAO.address,
        cao_parameters: state.contracts.CAOParameters.address,
        human_resouces: state.contracts.HumanResources.address,
        fund: state.contracts.MainFund.address,
        ops_governor: state.contracts.OpsGovernor.address,
        utils: {
            pancakeswap_lp_farming_util: state.contracts.PancakeswapLpFarmingUtil.address,
        },
        fund_token: state.contracts.MainFundToken.address,
        front_office_parameters: state.contracts.FrontOfficeParameters.address,
        front_office: state.contracts.FrontOffice.address,
        accounting: state.contracts.Accounting.address,
        incentives_manager: state.contracts.IncentivesManager.address,
        incentives: {
            referral_incentive: state.contracts.ReferralIncentive.address,
        },
    };

    const dir = "outputs/bsc-mainnet-qa/v2/";

    !fs.existsSync(dir) && fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(dir + "addresses.yaml", yaml.dump(addressesOutput));

    return state;
};
