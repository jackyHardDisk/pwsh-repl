// C# extractor
// Extracted from vibe_tools for loraxMod

const { TreeSitterExtractor } = require('./base-extractor');

class CSharpExtractor extends TreeSitterExtractor {
  constructor() {
    super('csharp');
  }

  processNode(node, ancestors) {
    switch (node.type) {
      case 'class_declaration':
        const className = node.childForFieldName('name')?.text;
        const baseClass = node.childForFieldName('bases')?.firstChild?.text;
        if (className) {
          this.addSegment(node, 'class', className, ancestors, { extends: baseClass });
        }
        break;

      case 'interface_declaration':
        const interfaceName = node.childForFieldName('name')?.text;
        if (interfaceName) {
          this.addSegment(node, 'interface', interfaceName, ancestors);
        }
        break;

      case 'struct_declaration':
        const structName = node.childForFieldName('name')?.text;
        if (structName) {
          this.addSegment(node, 'struct', structName, ancestors);
        }
        break;

      case 'enum_declaration':
        const enumName = node.childForFieldName('name')?.text;
        if (enumName) {
          this.addSegment(node, 'enum', enumName, ancestors);
        }
        break;

      case 'method_declaration':
        const methodName = node.childForFieldName('name')?.text;
        if (methodName) {
          this.addSegment(node, 'method', methodName, ancestors);
        }
        break;

      case 'constructor_declaration':
        const parentClass = ancestors.find(a => a.type === 'class_declaration');
        const ctorName = parentClass?.childForFieldName('name')?.text;
        if (ctorName) {
          this.addSegment(node, 'constructor', ctorName, ancestors);
        }
        break;

      case 'property_declaration':
        const propertyDeclarators = node.descendantsOfType('variable_declarator');
        propertyDeclarators.forEach(declarator => {
          const propName = declarator.childForFieldName('name')?.text;
          if (propName) {
            this.addSegment(node, 'property', propName, ancestors);
          }
        });
        break;

      case 'field_declaration':
        const fieldDeclarators = node.descendantsOfType('variable_declarator');
        const modifiers = node.childForFieldName('modifiers')?.text || '';

        fieldDeclarators.forEach(declarator => {
          const fieldName = declarator.childForFieldName('name')?.text;
          if (fieldName) {
            if (modifiers.includes('const') ||
                (modifiers.includes('readonly') && modifiers.includes('static'))) {
              this.addSegment(node, 'constant', fieldName, ancestors);
            } else {
              this.addSegment(node, 'field', fieldName, ancestors);
            }
          }
        });
        break;

      case 'local_function_statement':
        const localFuncName = node.childForFieldName('name')?.text;
        if (localFuncName) {
          this.addSegment(node, 'function', localFuncName, ancestors);
        }
        break;

      case 'delegate_declaration':
        const delegateName = node.childForFieldName('name')?.text;
        if (delegateName) {
          this.addSegment(node, 'delegate', delegateName, ancestors);
        }
        break;

      case 'record_declaration':
        const recordName = node.childForFieldName('name')?.text;
        if (recordName) {
          this.addSegment(node, 'record', recordName, ancestors);
        }
        break;
    }
  }
}

// Register processor
function processCSharpNode(node, ancestors, extractor) {
  const csExtractor = new CSharpExtractor();
  csExtractor.processNode(node, ancestors);
}

TreeSitterExtractor.register('csharp', processCSharpNode);

module.exports = {
  CSharpExtractor,
  processCSharpNode
};
