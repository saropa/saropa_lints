/**
 * Tree items barrel file.
 * Re-exports classes and builders from split modules for backward compatibility.
 */

// Re-export all classes
export {
    categoryColor,
    severityIcon,
    severityColor,
    PackageItem,
    SuppressedGroupItem,
    SectionGroupItem,
    SuppressedPackageItem,
    DetailItem,
    SourceCodeItem,
    GroupChildItem,
    PrereleaseItem,
    GroupItem,
    DepGraphSummaryItem,
    OverridesGroupItem,
    OverrideItem,
    ActionItemsGroupItem,
    InsightItem,
    BudgetGroupItem,
    BudgetItem,
    SeverityGroupItem,
} from './tree-item-classes';

// Re-export all builders
export {
    buildGroupItems,
    buildDependencyGroup,
    buildDepGraphSummaryDetails,
    buildOverrideDetails,
    buildInsightDetails,
} from './tree-item-builders';
