// Fortran extractor
// Supports: programs, modules, submodules, block data, subroutines, functions,
//           module procedures, derived types, interfaces, parameters

const { TreeSitterExtractor } = require('./base-extractor');

class FortranExtractor extends TreeSitterExtractor {
  constructor() {
    super('fortran');
  }

  processNode(node, ancestors) {
    switch (node.type) {
      case 'program':
        const programStmt = node.child(0);
        // program_statement has no 'name' field, name is child(1) with type 'name'
        const programName = programStmt?.child(1)?.text;
        if (programName) {
          this.addSegment(node, 'program', programName, ancestors);
        }
        break;

      case 'block_data':
        const blockDataStmt = node.child(0);
        // block_data_statement: child(0)=block, child(1)=data, child(2)=name
        const blockDataName = blockDataStmt?.child(2)?.text;
        if (blockDataName) {
          this.addSegment(node, 'block_data', blockDataName, ancestors);
        }
        break;

      case 'module':
        const moduleStmt = node.child(0);
        // module_statement has no 'name' field, name is child(1) with type 'name'
        const moduleName = moduleStmt?.child(1)?.text;
        if (moduleName) {
          this.addSegment(node, 'module', moduleName, ancestors);
        }
        break;

      case 'submodule':
        const submoduleStmt = node.child(0);
        // submodule_statement: child(0)=keyword, child(1-3)=parent ref, child(4)=name
        const submoduleName = submoduleStmt?.child(4)?.text;
        if (submoduleName) {
          this.addSegment(node, 'submodule', submoduleName, ancestors);
        }
        break;

      case 'subroutine':
        const subroutineStmt = node.child(0);
        const subroutineName = subroutineStmt?.childForFieldName('name')?.text;
        if (subroutineName) {
          this.addSegment(node, 'subroutine', subroutineName, ancestors);
        }
        break;

      case 'function':
        const functionStmt = node.child(0);
        const functionName = functionStmt?.childForFieldName('name')?.text;
        if (functionName) {
          this.addSegment(node, 'function', functionName, ancestors);
        }
        break;

      case 'module_procedure':
        const moduleProcStmt = node.child(0);
        // module_procedure_statement has named field 'name'
        const moduleProcName = moduleProcStmt?.childForFieldName('name')?.text;
        if (moduleProcName) {
          this.addSegment(node, 'module_procedure', moduleProcName, ancestors);
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
        // Handle parameter constants with PARAMETER attribute (modern syntax)
        if (this.hasParameterAttribute(node)) {
          const varNames = this.extractVariableNames(node);
          varNames.forEach(name => {
            if (name && !this.isFortranKeyword(name)) {
              this.addSegment(node, 'parameter', name, ancestors);
            }
          });
        }
        break;

      case 'parameter_statement':
        // Handle old-style PARAMETER statement
        const assignments = node.children.filter(child => child.type === 'parameter_assignment');
        assignments.forEach(assignment => {
          const identifier = assignment.children.find(child => child.type === 'identifier');
          if (identifier && identifier.text) {
            this.addSegment(assignment, 'parameter', identifier.text, ancestors);
          }
        });
        break;
    }
  }

  /**
   * Check if variable declaration has PARAMETER attribute (structural check)
   */
  hasParameterAttribute(declarationNode) {
    // Look for type_qualifier child with PARAMETER keyword
    for (const child of declarationNode.children) {
      if (child.type === 'type_qualifier') {
        // Check if this qualifier contains 'PARAMETER' keyword
        const parameterKeyword = child.children.find(c => c.type === 'parameter');
        if (parameterKeyword) {
          return true;
        }
      }
    }
    return false;
  }

  /**
   * Extract variable names from declarations (improved with keyword filtering)
   */
  extractVariableNames(node) {
    const names = [];

    // Look for init_declarator nodes (modern syntax: name = value)
    const declarators = node.children.filter(child => child.type === 'init_declarator');
    for (const decl of declarators) {
      const leftNode = decl.childForFieldName('left');
      if (leftNode && leftNode.type === 'identifier') {
        names.push(leftNode.text);
      }
    }

    // Fallback: look for plain identifier nodes (simple declarations)
    if (names.length === 0) {
      const identifiers = node.children.filter(child => child.type === 'identifier');
      for (const id of identifiers) {
        if (id.text && id.text.length > 0 && !this.isFortranKeyword(id.text)) {
          names.push(id.text);
        }
      }
    }

    // Remove duplicates
    return [...new Set(names)];
  }

  /**
   * Check if string is Fortran keyword (to avoid extracting type names as variables)
   */
  isFortranKeyword(text) {
    const keywords = [
      'INTEGER', 'REAL', 'DOUBLE', 'PRECISION', 'COMPLEX',
      'CHARACTER', 'LOGICAL', 'PARAMETER', 'DIMENSION',
      'ALLOCATABLE', 'POINTER', 'TARGET', 'INTENT',
      'PUBLIC', 'PRIVATE', 'SAVE', 'EXTERNAL'
    ];
    return keywords.includes(text.toUpperCase());
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
