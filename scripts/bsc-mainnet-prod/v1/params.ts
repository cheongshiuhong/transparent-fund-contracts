// Libraries
import { ethers } from "ethers";

/** Constants */
export default {
    CAO_TOKEN_NAME: "Material",
    CAO_TOKEN_SYMBOL: "MTRL",
    CAO_TOKEN_PER_PERSON: ethers.utils.parseEther("100"),
    FUND_TOKEN_NAME: "Transparent",
    FUND_TOKEN_SYMBOL: "TRNS",
    MAX_SINGLE_WITHDRAWAL_FT_AMOUNT: ethers.utils.parseEther("10000"),
    EVALUATION_PERIOD_BLOCKS: 864000, // 30 days
    MIN_EVALUATION_PERIOD_BLOCKS: 28800, // 1 day
    MANAGEMENT_FEE: ethers.utils.parseEther("0.2"),
    MAX_MANAGEMENT_FEE: ethers.utils.parseEther("0.5"),

    INITIAL_AUM_VALUE: ethers.utils.parseEther("1"),
    INITIAL_FT_SUPPLY: ethers.utils.parseEther("1"), // $1 per ether
};
