// Bash extractor
// Extracted from vibe_tools for loraxMod

const { TreeSitterExtractor } = require('./base-extractor');

class BashExtractor extends TreeSitterExtractor {
  constructor() {
    super('bash');
  }

  processNode(node, ancestors) {
    switch (node.type) {
      case 'function_definition':
        const functionName = node.childForFieldName('name')?.text;
        if (functionName) {
          this.addSegment(node, 'function', functionName, ancestors);
        }
        break;

      case 'variable_assignment':
        const varName = node.childForFieldName('name')?.text;
        const value = node.childForFieldName('value')?.text;

        // Check for readonly/declare -r patterns
        if (varName && (value?.includes('readonly') || ancestors.some(a => a.text?.includes('declare -r')))) {
          this.addSegment(node, 'constant', varName, ancestors);
        }
        break;

      case 'command':
        // Handle export commands
        if (node.firstChild?.text === 'export') {
          const exportVar = node.children[1]?.text;
          if (exportVar) {
            this.addSegment(node, 'export', exportVar, ancestors);
            this.addSegment(node, 'global', exportVar, ancestors);
          }
        }
        break;
    }
  }
}

// Register processor
function processBashNode(node, ancestors, extractor) {
  const bashExtractor = new BashExtractor();
  bashExtractor.processNode(node, ancestors);
}

TreeSitterExtractor.register('bash', processBashNode);

module.exports = {
  BashExtractor,
  processBashNode
};
