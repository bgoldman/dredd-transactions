
clone = require('clone')

{child, children, parent, content} = require('./refract')
validateParameters = require('../validate-parameters')
detectTransactionExamples = require('./detect-transaction-examples')
expandUriTemplateWithParameters = require('../expand-uri-template-with-parameters')


compileFromApiElements = (parseResult, filename) ->
  transactions = []
  annotations = []

  for annotation in children(parseResult, {element: 'annotation'})
    annotations.push(
      type: annotation.meta.classes[0]
      component: 'apiDescriptionParser'
      code: content(annotation.attributes?.code)
      message: content(annotation)
      location: content(child(annotation.attributes?.sourceMap, {element: 'sourceMap'}))
    )

  children(parseResult, {element: 'transition'}).map(detectTransactionExamples)

  for httpTransaction in children(parseResult, {element: 'httpTransaction'})
    resource = parent(httpTransaction, parseResult, {element: 'resource'})
    httpRequest = child(httpTransaction, {element: 'httpRequest'})
    httpResponse = child(httpTransaction, {element: 'httpResponse'})

    origin = compileOrigin(filename, parseResult, httpTransaction)
    result = compileRequest(parseResult, httpRequest)

    for annotation in result.annotations
      annotation.origin = clone(origin)
      annotations.push(annotation)

    transactions.push({
      origin
      pathOrigin: compilePathOrigin(filename, parseResult, httpTransaction)
      request: result.request
      response: compileResponse(httpResponse)
    })

  {transactions, annotations}


compileRequest = (parseResult, httpRequest) ->
  messageBody = child(httpRequest, {element: 'asset', 'meta.classes': 'messageBody'})
  result = compileUri(parseResult, httpRequest)
  {
    request:
      method: content(httpRequest.attributes.method)
      uri: result.uri
      headers: compileHeaders(child(httpRequest, {element: 'httpHeaders'}))
      body: content(messageBody) or ''
    annotations: result.annotations
  }


compileResponse = (httpResponse) ->
  messageBody = child(httpResponse, {element: 'asset', 'meta.classes': 'messageBody'})
  messageBodySchema = child(httpResponse, {element: 'asset', 'meta.classes': 'messageBodySchema'})

  response =
    status: content(httpResponse.attributes.statusCode)
    headers: compileHeaders(child(httpResponse, {element: 'httpHeaders'}))
    body: content(messageBody) or ''

  schema = content(messageBodySchema)
  response.schema = schema if schema

  response


compileUri = (parseResult, httpRequest) ->
  resource = parent(httpRequest, parseResult, {element: 'resource'})
  transition = parent(httpRequest, parseResult, {element: 'transition'})

  cascade = [
    resource.attributes
    transition.attributes
    httpRequest.attributes
  ]

  parameters = {}
  annotations = []
  href = undefined

  for attributes in cascade
    href = content(attributes.href) if attributes?.href
    for own name, parameter of compileParameters(attributes?.hrefVariables)
      parameters[name] = parameter

  result = validateParameters(parameters)
  component = 'parametersValidation'
  for error in result.errors
    annotations.push({type: 'error', component, message: error})
  for warning in result.warnings
    annotations.push({type: 'warning', component, message: warning})

  result = expandUriTemplateWithParameters(href, parameters)
  component = 'uriTemplateExpansion'
  for error in result.errors
    annotations.push({type: 'error', component, message: error})
  for warning in result.warnings
    annotations.push({type: 'warning', component, message: warning})

  {uri: result.uri, annotations}


compileParameters = (hrefVariables) ->
  parameters = {}

  for member in content(hrefVariables) or []
    {key, value} = content(member)

    name = content(key)
    types = (content(member.attributes?.typeAttributes) or [])

    if value?.element is 'enum'
      example = content(content(value)[0])
    else
      example = content(value)

    parameters[name] =
      required: 'required' in types
      default: content(value.attributes?.default)
      example: example
      values: if value?.element is 'enum' then ({value: content(v)} for v in content(value)) else []
  parameters


compileHeaders = (httpHeaders) ->
  headers = {}
  for member in children(httpHeaders, {element: 'member'})
    name = content(content(member).key)
    value = content(content(member).value)
    headers[name] = {value}
  headers


compileOrigin = (filename, parseResult, httpTransaction) ->
  api = parent(httpTransaction, parseResult, {element: 'category', 'meta.classes': 'api'})
  resourceGroup = parent(httpTransaction, parseResult, {element: 'category', 'meta.classes': 'resourceGroup'})
  resource = parent(httpTransaction, parseResult, {element: 'resource'})
  transition = parent(httpTransaction, parseResult, {element: 'transition'})
  httpRequest = child(httpTransaction, {element: 'httpRequest'})

  if content(transition.attributes.examples) > 1
    exampleName = "Example #{httpTransaction.attributes.example}"
  else
    exampleName = ''

  {
    filename: filename or null
    apiName: content(api.meta?.title) or filename or null
    resourceGroupName: content(resourceGroup?.meta?.title)
    resourceName: content(resource.meta?.title) or content(resource.attributes?.href)
    actionName: content(transition.meta?.title) or content(httpRequest.attributes.method)
    exampleName
  }


compilePathOrigin = (filename, parseResult, httpTransaction) ->
  api = parent(httpTransaction, parseResult, {element: 'category', 'meta.classes': 'api'})
  resourceGroup = parent(httpTransaction, parseResult, {element: 'category', 'meta.classes': 'resourceGroup'})
  resource = parent(httpTransaction, parseResult, {element: 'resource'})
  transition = parent(httpTransaction, parseResult, {element: 'transition'})
  httpRequest = child(httpTransaction, {element: 'httpRequest'})

  {
    apiName: content(api.meta?.title)
    resourceGroupName: content(resourceGroup?.meta?.title)
    resourceName: content(resource.meta?.title) or content(resource.attributes?.href)
    actionName: content(transition.meta?.title) or content(httpRequest.attributes.method)
    exampleName: "Example #{httpTransaction.attributes.example}"
  }


module.exports = compileFromApiElements
