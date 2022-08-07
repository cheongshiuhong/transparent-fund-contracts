// Types
import { TokensConfig, PancakeswapConfig, VenusConfig, Config } from "./interfaces";

// Libraries
import fs from "fs";
import yaml from "js-yaml";

const loadConfig = (): Config => {
    const path = "configs/bsc-mainnet/";

    // Read the config
    const tokens = yaml.load(fs.readFileSync(path + "tokens.yaml").toString()) as TokensConfig;
    const pancakeswap = yaml.load(fs.readFileSync(path + "protocols/pancakeswap.yaml").toString()) as PancakeswapConfig;
    const venus = yaml.load(fs.readFileSync(path + "protocols/venus.yaml").toString()) as VenusConfig;

    return { tokens, pancakeswap, venus };
};

export default loadConfig;
