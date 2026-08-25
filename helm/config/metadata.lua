-- Rendered through Helm `tpl` for the parameter list below, so no Go-template braces in Lua code.
-- Parameters carrying credentials (the OPA check reads the client's JWT from a token arg), from
-- fluentbit.maskQueryParams; an empty list makes mask() a no-op.
local MASKED_PARAMS = { {{ range $i, $param := .Values.fluentbit.maskQueryParams }}{{ if $i }}, {{ end }}{{ $param | quote }}{{ end }} }
local MASK = "[MASKED]"
local MASKED_FIELDS = { "url.query", "url.full" }

-- Mask in a bare query ("a=1&token=x"), a target ("/p?token=x") or a request line alike. Lua
-- patterns have no alternation or word boundaries, so each name is matched with its `?`/`&`
-- delimiter (else `token` also matches `access_token=`) and the leading "&" gives the first
-- parameter one too. Stopping the value at `&` or whitespace keeps the trailing " HTTP/1.1".
local function mask(value)
    if type(value) ~= "string" then
        return value
    end

    local masked, total = "&" .. value, 0
    for _, param in ipairs(MASKED_PARAMS) do
        -- %W escapes the name's non-alphanumerics into pattern literals.
        local pattern = "([?&]" .. param:gsub("(%W)", "%%%1") .. "=)[^&%s]*"
        local count
        masked, count = masked:gsub(pattern, "%1" .. MASK)
        total = total + count
    end

    if total == 0 then
        return value
    end
    return masked:sub(2)
end

-- Its own filter rather than part of flatten_attributes below, so it can run ahead of the
-- operator's forwardedOnly hook while `record["Attributes"]` is still reachable.
function mask_query_params(tag, timestamp, group, metadata, record)
    local modified = false

    local attributes = record["Attributes"]
    if type(attributes) == "table" then
        for _, field in ipairs(MASKED_FIELDS) do
            local masked = mask(attributes[field])
            if masked ~= attributes[field] then
                attributes[field] = masked
                modified = true
            end
        end
    end

    -- `Body` is nginx's $request: the whole request line, query included.
    local body = mask(record["Body"])
    if body ~= record["Body"] then
        record["Body"] = body
        modified = true
    end

    -- Code 0 keeps the record as it arrived, discarding the edits above.
    if modified then
        return 1, timestamp, metadata, record
    else
        return 0, timestamp, metadata, record
    end
end

-- Lift the decoded access-log `Attributes` into the record's OTLP metadata, which the
-- opentelemetry output maps to the log record's attributes. No filter can write metadata, so
-- this has to be Lua: returning 4 values marks the 3rd as metadata. `Resource` is dropped —
-- resource attributes are set by the output's processors instead.
function flatten_attributes(tag, timestamp, group, metadata, record)
    local metadata = {}
    local modified = false

    if type(record["Attributes"]) == "table" then
        for k, v in pairs(record["Attributes"]) do
            -- nginx writes "" for variables with no value on this request; skip those.
            if v ~= "" then
                metadata[k] = v
            end
        end
        record["Attributes"] = nil
        modified = true
    end

    if record["Resource"] ~= nil then
        record["Resource"] = nil
        modified = true
    end

    if modified then
        return 1, timestamp, metadata, record
    else
        return 0, timestamp, metadata, record
    end
end

-- nginx severity -> OTel SeverityNumber (INFO 9-12, WARN 13-16, ERROR 17-20, FATAL 21-24).
local SEVERITY_NUMBERS = {
    debug = 5, info = 9, notice = 10, warn = 13,
    error = 17, crit = 18, alert = 21, emerg = 22,
}

-- Rewrite the error-log record the nginx_error parser produced into the same envelope the access
-- log arrives in: semantic-convention attributes in metadata, the message as `Body`, the nginx
-- level as OTel severity. Without this its fields keep the parser's own names (client, pid,
-- request, …) and land in Loki as attributes no dashboard shares with the access log.
function envelope_error(tag, timestamp, group, metadata, record)
    local attributes = {}

    if record["client"] ~= nil and record["client"] ~= "" then
        attributes["client.address"] = record["client"]
    end
    if record["server"] ~= nil and record["server"] ~= "" then
        attributes["server.address"] = record["server"]
    end
    if record["pid"] ~= nil then
        attributes["process.pid"] = tonumber(record["pid"]) or record["pid"]
    end

    -- The request line ("GET /path?q=1 HTTP/1.1") only appears on messages tied to a request.
    local request = record["request"]
    if request ~= nil and request ~= "" then
        local method, target, version = string.match(request, "^(%S+) (%S+) HTTP/(%S+)$")
        if method ~= nil then
            attributes["http.request.method"] = method
            attributes["network.protocol.name"] = "http"
            attributes["network.protocol.version"] = version
            local path, query = string.match(target, "^([^?]*)%??(.*)$")
            attributes["url.path"] = path
            if query ~= "" then
                -- The error line quotes the same request line as the access log, token and all.
                attributes["url.query"] = mask(query)
            end
        else
            -- Not a well-formed request line (a malformed request is itself a common error).
            attributes["mapcolonies.request"] = request
        end
    end

    local envelope = {
        Body = record["message"],
        InstrumentationScope = "error.log",
    }
    local level = record["level"]
    if level ~= nil then
        envelope["SeverityText"] = level
        envelope["SeverityNumber"] = SEVERITY_NUMBERS[string.lower(level)] or 9
    end

    return 1, timestamp, attributes, envelope
end
