// Fortran extractor
// Supports: programs, modules, subroutines, functions, derived types

const { TreeSitterExtractor } = require('./base-extractor');

class FortranExtractor extends TreeSitterExtractor {
  constructor() {
    super('fortran');
  }

  processNode(node, ancestors) {
    switch (node.type) {
      case 'program':
        const programName = node.childForFieldName('name')?.text;
        if (programName) {
          this.addSegment(node, 'program', programName, ancestors);
        }
        break;

      case 'module':
        const moduleName = node.childForFieldName('name')?.text;
        if (moduleName) {
          this.addSegment(node, 'module', moduleName, ancestors);
        }
        break;

      case 'subroutine':
        const subroutineName = node.childForFieldName('name')?.text;
        if (subroutineName) {
          this.addSegment(node, 'subroutine', subroutineName, ancestors);
        }
        break;

      case 'function':
        const functionName = node.childForFieldName('name')?.text;
        if (functionName) {
          this.addSegment(node, 'function', functionName, ancestors);
        }
        break;

      case 'derived_type_definition':
        const typeName = node.childForFieldName('name')?.text;
        if (typeName) {
          this.addSegment(node, 'derived_type', typeName, ancestors);
        }
        break;

      case 'interface':
        const interfaceName = node.childForFieldName('name')?.text;
        if (interfaceName) {
          this.addSegment(node, 'interface', interfaceName, ancestors);
        }
        break;

      case 'variable_declaration':
        // Handle parameter constants (Fortran PARAMETER keyword)
        const isParameter = node.text.toLowerCase().includes('parameter');
        if (isParameter) {
          const varNames = this.extractVariableNames(node);
          varNames.forEach(name => {
            this.addSegment(node, 'parameter', name, ancestors);
          });
        }
        break;
    }
  }

  // Helper to extract variable names from declarations
  extractVariableNames(node) {
    const names = [];
    const identifiers = node.descendantsOfType('identifier');
    identifiers.forEach(id => {
      if (id.text && id.text.length > 0) {
        names.push(id.text);
      }
    });
    return names;
  }
}

// Register processor
function processFortranNode(node, ancestors, extractor) {
  const fortranExtractor = new FortranExtractor();
  fortranExtractor.processNode(node, ancestors);
}

TreeSitterExtractor.register('fortran', processFortranNode);

module.exports = {
  FortranExtractor,
  processFortranNode
};
