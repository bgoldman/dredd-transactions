
createOriginSchema = require('./origin')
createPathOriginSchema = require('./path-origin')


addMinMax = (schema, n) ->
  if n is true
    schema.minItems = 1
  else
    schema.minItems = n
    schema.maxItems = n
  schema


module.exports = (options = {}) ->
  # Either filename string or undefined (= doesn't matter)
  filename = options.filename

  # Either exact number or true (= more than one)
  errors = options.errors or 0
  warnings = options.warnings or 0
  transactions = options.transactions or 0

  # Either false (= no transaction names and paths should be present) or it
  # will default to true (= structure must contain transaction names and paths)
  paths = if options.paths is false then false else true

  requestSchema =
    type: 'object'
    properties:
      uri: {type: 'string', pattern: '^/'}
      method: {type: 'string'}
      headers:
        type: 'object'
        patternProperties:
          '': # property of any name
            type: 'object'
            properties:
              value: {type: 'string'}
      body: {type: 'string'}
    required: ['uri', 'method', 'headers']
    additionalProperties: false

  responseSchema =
    type: 'object'
    properties:
      status: {type: 'string'}
      headers:
        type: 'object'
        patternProperties:
          '': # property of any name
            type: 'object'
            properties:
              value: {type: 'string'}
      body: {type: 'string'}
    required: ['status', 'headers', 'body']
    additionalProperties: false

  originSchema = createOriginSchema({filename})
  pathOriginSchema = createPathOriginSchema()

  transactionSchema =
    type: 'object'
    properties:
      request: requestSchema
      response: responseSchema
      origin: originSchema
      pathOrigin: pathOriginSchema
    required: ['request', 'response', 'origin', 'pathOrigin']
    additionalProperties: false

  if paths
    transactionSchema.properties.name = {type: 'string'}
    transactionSchema.required.push('name')
    transactionSchema.properties.path = {type: 'string'}
    transactionSchema.required.push('path')

  transactionsSchema = addMinMax({type: 'array', items: transactionSchema}, transactions)
  errorsSchema = addMinMax({type: 'array'}, errors)
  warningsSchema = addMinMax({type: 'array'}, warnings)

  {
    type: 'object'
    properties:
      transactions: transactionsSchema
      errors: errorsSchema
      warnings: warningsSchema
    required: ['transactions', 'errors', 'warnings']
    additionalProperties: false
  }
