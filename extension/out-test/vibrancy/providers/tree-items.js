"use strict";
/**
 * Tree items barrel file.
 * Re-exports classes and builders from split modules for backward compatibility.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildInsightDetails = exports.buildOverrideDetails = exports.buildDepGraphSummaryDetails = exports.buildDependencyGroup = exports.buildGroupItems = exports.BudgetItem = exports.BudgetGroupItem = exports.InsightItem = exports.ActionItemsGroupItem = exports.OverrideItem = exports.OverridesGroupItem = exports.DepGraphSummaryItem = exports.GroupItem = exports.PrereleaseItem = exports.DetailItem = exports.SuppressedPackageItem = exports.SectionGroupItem = exports.SuppressedGroupItem = exports.PackageItem = exports.severityColor = exports.severityIcon = exports.categoryColor = void 0;
// Re-export all classes
var tree_item_classes_1 = require("./tree-item-classes");
Object.defineProperty(exports, "categoryColor", { enumerable: true, get: function () { return tree_item_classes_1.categoryColor; } });
Object.defineProperty(exports, "severityIcon", { enumerable: true, get: function () { return tree_item_classes_1.severityIcon; } });
Object.defineProperty(exports, "severityColor", { enumerable: true, get: function () { return tree_item_classes_1.severityColor; } });
Object.defineProperty(exports, "PackageItem", { enumerable: true, get: function () { return tree_item_classes_1.PackageItem; } });
Object.defineProperty(exports, "SuppressedGroupItem", { enumerable: true, get: function () { return tree_item_classes_1.SuppressedGroupItem; } });
Object.defineProperty(exports, "SectionGroupItem", { enumerable: true, get: function () { return tree_item_classes_1.SectionGroupItem; } });
Object.defineProperty(exports, "SuppressedPackageItem", { enumerable: true, get: function () { return tree_item_classes_1.SuppressedPackageItem; } });
Object.defineProperty(exports, "DetailItem", { enumerable: true, get: function () { return tree_item_classes_1.DetailItem; } });
Object.defineProperty(exports, "PrereleaseItem", { enumerable: true, get: function () { return tree_item_classes_1.PrereleaseItem; } });
Object.defineProperty(exports, "GroupItem", { enumerable: true, get: function () { return tree_item_classes_1.GroupItem; } });
Object.defineProperty(exports, "DepGraphSummaryItem", { enumerable: true, get: function () { return tree_item_classes_1.DepGraphSummaryItem; } });
Object.defineProperty(exports, "OverridesGroupItem", { enumerable: true, get: function () { return tree_item_classes_1.OverridesGroupItem; } });
Object.defineProperty(exports, "OverrideItem", { enumerable: true, get: function () { return tree_item_classes_1.OverrideItem; } });
Object.defineProperty(exports, "ActionItemsGroupItem", { enumerable: true, get: function () { return tree_item_classes_1.ActionItemsGroupItem; } });
Object.defineProperty(exports, "InsightItem", { enumerable: true, get: function () { return tree_item_classes_1.InsightItem; } });
Object.defineProperty(exports, "BudgetGroupItem", { enumerable: true, get: function () { return tree_item_classes_1.BudgetGroupItem; } });
Object.defineProperty(exports, "BudgetItem", { enumerable: true, get: function () { return tree_item_classes_1.BudgetItem; } });
// Re-export all builders
var tree_item_builders_1 = require("./tree-item-builders");
Object.defineProperty(exports, "buildGroupItems", { enumerable: true, get: function () { return tree_item_builders_1.buildGroupItems; } });
Object.defineProperty(exports, "buildDependencyGroup", { enumerable: true, get: function () { return tree_item_builders_1.buildDependencyGroup; } });
Object.defineProperty(exports, "buildDepGraphSummaryDetails", { enumerable: true, get: function () { return tree_item_builders_1.buildDepGraphSummaryDetails; } });
Object.defineProperty(exports, "buildOverrideDetails", { enumerable: true, get: function () { return tree_item_builders_1.buildOverrideDetails; } });
Object.defineProperty(exports, "buildInsightDetails", { enumerable: true, get: function () { return tree_item_builders_1.buildInsightDetails; } });
//# sourceMappingURL=tree-items.js.map