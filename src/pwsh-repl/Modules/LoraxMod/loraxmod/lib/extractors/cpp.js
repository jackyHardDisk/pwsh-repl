// C++ extractor
// Supports: classes, structs, namespaces, functions, methods, enums, typedefs, templates

const { TreeSitterExtractor } = require('./base-extractor');
const { findAncestor } = require('../core/traversal');

class CppExtractor extends TreeSitterExtractor {
  constructor() {
    super('cpp');
  }

  processNode(node, ancestors) {
    switch (node.type) {
      case 'class_specifier':
      case 'struct_specifier':
        this.processClassOrStruct(node, ancestors);
        break;

      case 'namespace_definition':
        this.processNamespace(node, ancestors);
        break;

      case 'function_definition':
        this.processFunction(node, ancestors);
        break;

      case 'template_declaration':
        this.processTemplate(node, ancestors);
        break;

      case 'enum_specifier':
        this.processEnum(node, ancestors);
        break;

      case 'type_definition':
        this.processTypedef(node, ancestors);
        break;

      case 'declaration':
        this.processDeclaration(node, ancestors);
        break;
    }
  }

  /**
   * Process class or struct declaration
   */
  processClassOrStruct(node, ancestors) {
    const className = node.childForFieldName('name')?.text;
    if (!className) return;

    const qualifiedName = this.getQualifiedName(className, ancestors);
    const type = node.type === 'class_specifier' ? 'class' : 'struct';

    // Extract base class if present
    const baseClause = node.childForFieldName('base_clause');
    let baseClass = null;
    if (baseClause) {
      // Simple extraction - just get text and clean it
      baseClass = baseClause.text
        .replace(/^:\s*/, '')           // Remove leading colon
        .replace(/public\s+/, '')       // Remove access specifier
        .replace(/private\s+/, '')
        .replace(/protected\s+/, '')
        .trim();
    }

    this.addSegment(node, type, qualifiedName, ancestors, { extends: baseClass });
  }

  /**
   * Process namespace definition
   */
  processNamespace(node, ancestors) {
    const namespaceName = node.childForFieldName('name')?.text;
    if (!namespaceName) return;

    const qualifiedName = this.getQualifiedName(namespaceName, ancestors);
    this.addSegment(node, 'namespace', qualifiedName, ancestors);
  }

  /**
   * Process function definition
   */
  processFunction(node, ancestors) {
    const declarator = node.childForFieldName('declarator');
    const funcName = this.getFunctionName(declarator);
    if (!funcName) return;

    // Determine if this is a method (inside class/struct) or free function
    const inClass = findAncestor(ancestors, ['class_specifier', 'struct_specifier']);
    const segmentType = inClass ? 'method' : 'function';

    const qualifiedName = this.getQualifiedName(funcName, ancestors);
    this.addSegment(node, segmentType, qualifiedName, ancestors);
  }

  /**
   * Process template declaration
   */
  processTemplate(node, ancestors) {
    // Find the templated body (class, function, etc.)
    const templateBody = node.children.find(child =>
      child.type === 'class_specifier' ||
      child.type === 'struct_specifier' ||
      child.type === 'function_definition'
    );

    if (templateBody) {
      // Process the template body with current ancestors
      // This will naturally create qualified names
      this.processNode(templateBody, ancestors);
    }
  }

  /**
   * Process enum declaration
   */
  processEnum(node, ancestors) {
    const enumName = node.childForFieldName('name')?.text;
    if (!enumName) return;

    const qualifiedName = this.getQualifiedName(enumName, ancestors);
    this.addSegment(node, 'enum', qualifiedName, ancestors);
  }

  /**
   * Process typedef or using declaration
   */
  processTypedef(node, ancestors) {
    const typeName = this.getTypedefName(node);
    if (!typeName) return;

    const qualifiedName = this.getQualifiedName(typeName, ancestors);
    this.addSegment(node, 'typedef', qualifiedName, ancestors);
  }

  /**
   * Process declaration (constants, variables)
   */
  processDeclaration(node, ancestors) {
    // Only extract constants at namespace/class scope
    if (this.isInFunction(ancestors)) return;

    if (this.isConstantDeclaration(node)) {
      const constName = this.getDeclaratorName(node);
      if (constName) {
        const qualifiedName = this.getQualifiedName(constName, ancestors);
        this.addSegment(node, 'constant', qualifiedName, ancestors);
      }
    }
  }

  /**
   * Extract function name from declarator node
   */
  getFunctionName(declaratorNode) {
    if (!declaratorNode) return null;

    // Handle function_declarator wrapping
    if (declaratorNode.type === 'function_declarator') {
      const innerDeclarator = declaratorNode.childForFieldName('declarator');
      return this.getFunctionName(innerDeclarator);
    }

    // Handle pointer declarators
    if (declaratorNode.type === 'pointer_declarator') {
      const innerDeclarator = declaratorNode.childForFieldName('declarator');
      return this.getFunctionName(innerDeclarator);
    }

    // Handle qualified identifiers (ns::Class::method)
    if (declaratorNode.type === 'qualified_identifier') {
      return declaratorNode.text;
    }

    // Handle simple identifiers
    if (declaratorNode.type === 'identifier' ||
        declaratorNode.type === 'field_identifier' ||
        declaratorNode.type === 'destructor_name') {
      return declaratorNode.text;
    }

    // Recursively search children
    for (const child of declaratorNode.children) {
      const name = this.getFunctionName(child);
      if (name) return name;
    }

    return null;
  }

  /**
   * Extract typedef name
   */
  getTypedefName(node) {
    const declarator = node.childForFieldName('declarator');
    if (declarator) {
      if (declarator.type === 'type_identifier') {
        return declarator.text;
      }
    }

    // Handle using declarations: using alias = type;
    if (node.text.includes('using')) {
      const match = node.text.match(/using\s+(\w+)\s*=/);
      return match ? match[1] : null;
    }

    return null;
  }

  /**
   * Extract declarator name from declaration
   */
  getDeclaratorName(node) {
    const declarator = node.childForFieldName('declarator');
    if (!declarator) return null;

    if (declarator.type === 'identifier') {
      return declarator.text;
    }

    // Handle init_declarator
    const name = declarator.childForFieldName('declarator');
    if (name && name.type === 'identifier') {
      return name.text;
    }

    return null;
  }

  /**
   * Check if declaration is a constant
   */
  isConstantDeclaration(node) {
    const text = node.text;
    return text.includes('constexpr') ||
           text.includes('const ') ||
           text.includes('static const') ||
           text.includes('inline const');
  }

  /**
   * Check if currently inside a function
   */
  isInFunction(ancestors) {
    return ancestors.some(a => a.type === 'function_definition');
  }

  /**
   * Build fully qualified name with namespace and class context
   */
  getQualifiedName(name, ancestors) {
    const namespaces = [];

    for (const ancestor of ancestors) {
      if (ancestor.type === 'namespace_definition') {
        const ns = ancestor.childForFieldName('name')?.text;
        if (ns) namespaces.push(ns);
      } else if (ancestor.type === 'class_specifier' || ancestor.type === 'struct_specifier') {
        const cls = ancestor.childForFieldName('name')?.text;
        if (cls) namespaces.push(cls);
      }
    }

    if (namespaces.length > 0) {
      return namespaces.join('::') + '::' + name;
    }

    return name;
  }
}

// Register processor
function processCppNode(node, ancestors, extractor) {
  const cppExtractor = new CppExtractor();
  cppExtractor.processNode(node, ancestors);
}

TreeSitterExtractor.register('cpp', processCppNode);

module.exports = {
  CppExtractor,
  processCppNode
};
