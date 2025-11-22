// PowerShell extractor
// Extracted from vibe_tools for loraxMod

const { TreeSitterExtractor } = require('./base-extractor');

class PowerShellExtractor extends TreeSitterExtractor {
  constructor() {
    super('powershell');
  }

  processNode(node, ancestors) {
    switch (node.type) {
      case 'class_statement':
      case 'class_definition':
        const className = node.childForFieldName('name')?.text || node.children.find(c => c.type === 'simple_name')?.text;
        const baseClass = node.childForFieldName('base_class')?.text;
        if (className) {
          this.addSegment(node, 'class', className, ancestors, { extends: baseClass });
        }
        break;

      case 'function_statement':
      case 'function_definition':
        const functionName = node.childForFieldName('name')?.text || node.children[1]?.text;
        if (functionName) {
          this.addSegment(node, 'function', functionName, ancestors);
        }
        break;

      case 'method_definition':
        const methodName = node.childForFieldName('name')?.text;
        if (methodName) {
          this.addSegment(node, 'method', methodName, ancestors);
        }
        break;

      case 'variable_assignment':
        const varNode = node.childForFieldName('variable');
        const varName = varNode?.text;

        // Check for global/script scope
        if (varName?.includes('$global:') || varName?.includes('$script:')) {
          const cleanName = varName.replace(/\$(global|script):/, '');
          this.addSegment(node, 'global', cleanName, ancestors);
        }
        // Check for readonly constants
        else if (varNode?.parent?.text?.includes('[readonly]')) {
          this.addSegment(node, 'constant', varName?.replace('$', ''), ancestors);
        }
        break;

      case 'export_statement':
        // Handle Export-ModuleMember
        const exportTarget = node.childForFieldName('target')?.text;
        if (exportTarget) {
          this.addSegment(node, 'export', exportTarget, ancestors);
        }
        break;
    }
  }
}

// Register processor
function processPowerShellNode(node, ancestors, extractor) {
  const psExtractor = new PowerShellExtractor();
  psExtractor.processNode(node, ancestors);
}

TreeSitterExtractor.register('powershell', processPowerShellNode);

module.exports = {
  PowerShellExtractor,
  processPowerShellNode
};
