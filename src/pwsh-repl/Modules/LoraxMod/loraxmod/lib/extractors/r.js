// R language extractor
// Extracted from vibe_tools for loraxMod

const { TreeSitterExtractor } = require('./base-extractor');

class RExtractor extends TreeSitterExtractor {
  constructor() {
    super('r');
  }

  processNode(node, ancestors) {
    switch (node.type) {
      case 'function_definition':
      case 'binary_operator':
        // Handle function <- function() or name <- function()
        if (node.type === 'binary_operator' && node.childForFieldName('operator')?.text === '<-') {
          const left = node.childForFieldName('lhs');  // R uses 'lhs' not 'left'
          const right = node.childForFieldName('rhs'); // R uses 'rhs' not 'right'

          // Check for function definitions
          if (right?.text?.startsWith('function')) {
            const functionName = left?.text;
            if (functionName) {
              this.addSegment(node, 'function', functionName, ancestors);
            }
          }
          // Check for R6 class definitions: MyClass <- R6::R6Class("MyClass", ...)
          else if (right?.type === 'call') {
            const funcNode = right.childForFieldName('function') || right.child(0);
            const callFunc = funcNode?.text;
            if (callFunc === 'R6Class' || callFunc?.endsWith('::R6Class')) {
              // Extract class name from first argument
              const args = right.childForFieldName('arguments') || right.child(1);
              if (args) {
                let className = null;
                for (const child of args.children) {
                  if (child.type === 'string') {
                    className = child.text.replace(/['"]/g, '');
                    break;
                  } else if (child.type === 'argument') {
                    const argValue = child.child(0);
                    if (argValue?.type === 'string') {
                      className = argValue.text.replace(/['"]/g, '');
                      break;
                    }
                  }
                }
                if (className) {
                  this.addSegment(node, 'class', className, ancestors, { type: 'R6' });
                }
              }
            }
          }
          // Check for S3 class assignment: class(obj) <- "ClassName"
          else if (left?.type === 'call' && left.childForFieldName('function')?.text === 'class') {
            const className = right?.text?.replace(/['"]/g, '');
            if (className) {
              this.addSegment(node, 'class', className, ancestors, { type: 'S3' });
            }
          }
          // Check for constants (uppercase names)
          else if (left?.text && /^[A-Z][A-Z._0-9]*$/.test(left.text)) {
            this.addSegment(node, 'constant', left.text, ancestors);
          }
        }
        break;

      case 'assignment':
        // Handle = assignments
        const target = node.childForFieldName('lhs')?.text;
        if (target && /^[A-Z][A-Z._0-9]*$/.test(target)) {
          this.addSegment(node, 'constant', target, ancestors);
        }
        break;

      case 'call':
        // Handle various R-specific calls
        const fnName = node.childForFieldName('function')?.text;

        // Handle S4 class definitions
        if (fnName === 'setClass') {
          const args = node.childForFieldName('arguments');
          if (args) {
            for (const child of args.children) {
              if (child.type === 'string') {
                const className = child.text.replace(/['"]/g, '');
                this.addSegment(node, 'class', className, ancestors, { type: 'S4' });
                break;
              } else if (child.type === 'argument') {
                const argValue = child.child(0);
                if (argValue?.type === 'string') {
                  const className = argValue.text.replace(/['"]/g, '');
                  this.addSegment(node, 'class', className, ancestors, { type: 'S4' });
                  break;
                }
              }
            }
          }
        }
        // Handle S4/S3 method definitions
        else if (fnName === 'setMethod' || fnName === 'setGeneric' || fnName === 'UseMethod') {
          const args = node.childForFieldName('arguments');
          if (args) {
            for (const child of args.children) {
              if (child.type === 'string') {
                const methodName = child.text.replace(/['"]/g, '');
                this.addSegment(node, 'method', methodName, ancestors);
                break;
              }
            }
          }
        }
        // Handle R6 class instantiation pattern (standalone calls)
        else if (!fnName && node.child(0)?.text?.endsWith('::R6Class')) {
          const actualFunc = node.child(0)?.text;
          if (actualFunc?.endsWith('::R6Class')) {
            const args = node.childForFieldName('arguments');
            if (args) {
              for (const child of args.children) {
                if (child.type === 'string') {
                  const className = child.text.replace(/['"]/g, '');
                  this.addSegment(node, 'class', className, ancestors, { type: 'R6' });
                  break;
                }
              }
            }
          }
        }
        else if (fnName === 'R6Class' || fnName?.endsWith('::R6Class')) {
          const args = node.childForFieldName('arguments');
          if (args) {
            for (const child of args.children) {
              if (child.type === 'string') {
                const className = child.text.replace(/['"]/g, '');
                this.addSegment(node, 'class', className, ancestors, { type: 'R6' });
                break;
              }
            }
          }
        }
        // Handle assign() for global variables
        else if (fnName === 'assign' || fnName === '<<-') {
          const varName = node.childForFieldName('arguments')?.firstChild?.text;
          if (varName) {
            this.addSegment(node, 'global', varName.replace(/[\"']/g, ''), ancestors);
          }
        }
        break;
    }
  }
}

// Register processor
function processRNode(node, ancestors, extractor) {
  const rExtractor = new RExtractor();
  rExtractor.processNode(node, ancestors);
}

TreeSitterExtractor.register('r', processRNode);

module.exports = {
  RExtractor,
  processRNode
};
