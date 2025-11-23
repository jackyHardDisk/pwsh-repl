#!/usr/bin/env node
/**
 * Streaming Query Parser - Long-running Node.js process for tree-sitter parsing
 *
 * Protocol: JSON commands via stdin, JSON responses via stdout
 * Commands: ping, parse, query, shutdown
 *
 * Usage: node streaming_query_parser.js
 */

const readline = require('readline');
const fs = require('fs');
const path = require('path');

// Import loraxmod library
const loraxModPath = path.join(__dirname, '..', 'loraxmod', 'lib', 'index.js');
const lorax = require(loraxModPath);

// Session state
const state = {
  startTime: Date.now(),
  filesProcessed: 0,
  queries: 0,
  errors: 0,
  lastError: null,
  parser: null,
  initialized: false
};

/**
 * Initialize parser and loraxmod library
 */
async function initialize() {
  try {
    await lorax.initParser();
    state.parser = lorax.getParser();
    state.initialized = true;
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

/**
 * Handle ping command - verify parser is responsive
 */
function handlePing(command) {
  return {
    status: 'pong',
    uptime: Date.now() - state.startTime,
    filesProcessed: state.filesProcessed,
    queries: state.queries,
    errors: state.errors,
    memoryUsage: process.memoryUsage()
  };
}

/**
 * Handle parse command - parse a file using loraxmod
 */
async function handleParse(command) {
  try {
    const { file, context } = command;

    if (!file) {
      throw new Error('Missing required parameter: file');
    }

    // Read file
    if (!fs.existsSync(file)) {
      throw new Error(`File not found: ${file}`);
    }

    const code = fs.readFileSync(file, 'utf-8');

    // Parse using loraxmod
    const segments = await lorax.parseCode(code, file, context);

    state.filesProcessed++;

    return {
      status: 'ok',
      result: {
        file: file,
        language: lorax.detectLanguage(file),
        segments: segments,
        segmentCount: segments.length,
        parseTime: 0 // loraxmod doesn't track this
      },
      stats: {
        filesProcessed: state.filesProcessed,
        queries: state.queries
      }
    };
  } catch (error) {
    state.errors++;
    state.lastError = {
      file: command.file,
      message: error.message,
      timestamp: Date.now()
    };

    return {
      status: 'error',
      error: {
        type: error.name || 'ParseError',
        message: error.message,
        file: command.file
      }
    };
  }
}

/**
 * Handle query command - parse file and run tree-sitter query
 */
async function handleQuery(command) {
  try {
    const { file, query, context } = command;

    if (!file) {
      throw new Error('Missing required parameter: file');
    }

    if (!query) {
      throw new Error('Missing required parameter: query');
    }

    // Read file
    if (!fs.existsSync(file)) {
      throw new Error(`File not found: ${file}`);
    }

    const code = fs.readFileSync(file, 'utf-8');
    const language = lorax.detectLanguage(file);

    // Initialize parser and load language
    await lorax.initParser();
    const languageObj = await lorax.loadLanguage(language);

    if (!languageObj) {
      throw new Error(`Failed to load grammar for language: ${language}`);
    }

    const parser = lorax.getParser();
    parser.setLanguage(languageObj);

    // Parse code
    const tree = parser.parse(code);

    // Execute query using deprecated lang.query() method (web-tree-sitter API)
    const tsQuery = languageObj.query(query);
    const captures = tsQuery.captures(tree.rootNode);

    // Format results
    const results = captures.map(capture => ({
      name: capture.name,
      text: capture.node.text,
      startPosition: capture.node.startPosition,
      endPosition: capture.node.endPosition,
      startIndex: capture.node.startIndex,
      endIndex: capture.node.endIndex
    }));

    state.filesProcessed++;
    state.queries++;

    return {
      status: 'ok',
      result: {
        file: file,
        language: language,
        queryResults: results,
        captureCount: results.length
      },
      stats: {
        filesProcessed: state.filesProcessed,
        queries: state.queries
      }
    };
  } catch (error) {
    state.errors++;
    state.lastError = {
      file: command.file,
      query: command.query,
      message: error.message,
      timestamp: Date.now()
    };

    return {
      status: 'error',
      error: {
        type: error.name || 'QueryError',
        message: error.message,
        file: command.file
      }
    };
  }
}

/**
 * Handle shutdown command - return final stats and exit
 */
function handleShutdown(command) {
  const uptime = Date.now() - state.startTime;

  return {
    status: 'shutdown',
    message: `Parser shutting down after ${Math.round(uptime / 1000)} seconds`,
    finalStats: {
      uptime: uptime,
      filesProcessed: state.filesProcessed,
      queries: state.queries,
      errors: state.errors,
      lastError: state.lastError,
      memoryUsage: process.memoryUsage()
    }
  };
}

/**
 * Process incoming command
 */
async function processCommand(line) {
  try {
    const command = JSON.parse(line);

    let response;

    switch (command.command) {
      case 'ping':
        response = handlePing(command);
        break;

      case 'parse':
        response = await handleParse(command);
        break;

      case 'query':
        response = await handleQuery(command);
        break;

      case 'shutdown':
        response = handleShutdown(command);
        console.log(JSON.stringify(response));
        process.exit(0);

      default:
        response = {
          status: 'error',
          error: {
            type: 'UnknownCommand',
            message: `Unknown command: ${command.command}`,
            validCommands: ['ping', 'parse', 'query', 'shutdown']
          }
        };
    }

    console.log(JSON.stringify(response));

  } catch (error) {
    const errorResponse = {
      status: 'error',
      error: {
        type: 'ProtocolError',
        message: error.message
      }
    };
    console.log(JSON.stringify(errorResponse));
  }
}

/**
 * Main entry point
 */
async function main() {
  // Initialize parser
  const initResult = await initialize();

  if (!initResult.success) {
    console.error(JSON.stringify({
      status: 'error',
      error: {
        type: 'InitializationError',
        message: initResult.error
      }
    }));
    process.exit(1);
  }

  // Set up readline interface for stdin
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
  });

  // Process each line as a command
  rl.on('line', async (line) => {
    await processCommand(line);
  });

  // Handle stdin close
  rl.on('close', () => {
    process.exit(0);
  });
}

// Start the parser
main().catch(error => {
  console.error(JSON.stringify({
    status: 'error',
    error: {
      type: 'FatalError',
      message: error.message
    }
  }));
  process.exit(1);
});
