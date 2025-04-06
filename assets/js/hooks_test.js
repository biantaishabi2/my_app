console.log("Loading hooks_test.js");
import Hooks from "./hooks";

// 输出所有钩子的名称
console.log("Available hooks:");
for (const hookName in Hooks) {
  console.log(`- ${hookName}`);
}

// 特别检查地区选择钩子
console.log("\nRegion hooks check:");
console.log("RegionSelectProvince exists:", !!Hooks.RegionSelectProvince);
console.log("RegionSelectCity exists:", !!Hooks.RegionSelectCity);
console.log("RegionSelectDistrict exists:", !!Hooks.RegionSelectDistrict);

export default {}; 