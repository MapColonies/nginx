import qs from "querystring";

const DENYLIST = {
  // Payloads
  cookie: true,
  authorization: true,
  "proxy-authorization": true,
  // Connection / Hop-by-Hop (Network Noise)
  connection: true,
  "keep-alive": true,
  "transfer-encoding": true,
  te: true,
  trailer: true,
  upgrade: true,

  // Cache State (State Noise)
  "cache-control": true,
  pragma: true,
  "if-match": true,
  "if-none-match": true,
  "if-modified-since": true,
  "if-unmodified-since": true,

  // Browser Privacy / Legacy (Unused Bloat)
  dnt: true,
  "sec-gpc": true,
  "upgrade-insecure-requests": true,
  "save-data": true,

  // Legacy Tracing (Dropping B3/Zipkin, implicitly keeping Otel W3C)
  b3: true,
  "x-b3-traceid": true,
  "x-b3-spanid": true,
  "x-b3-sampled": true,
};

// 2. Size Limit Configuration
const MAX_HEADER_LENGTH = 2048;

// 3. Exceptions to the size limit (Headers that are allowed to be large)
const LENGTH_EXCEPTIONS = {
  "x-api-key": true,
  referer: true,
};

function filterHeaders(r) {
  // Object.create(null) creates a pure dictionary with no prototype chain,
  // protecting against prototype pollution/injection attacks.
  const cleanHeaders = Object.create(null);

  for (const header in r.headersIn) {
    // Protect against inherited properties injection
    if (!Object.prototype.hasOwnProperty.call(r.headersIn, header)) {
      continue;
    }

    const key = header.toLowerCase();

    if (!DENYLIST[key]) {
      const headerValue = Array.isArray(r.headersIn[header])
        ? r.headersIn[header].join(", ")
        : r.headersIn[header];

      if (headerValue.length > MAX_HEADER_LENGTH && !LENGTH_EXCEPTIONS[key]) {
        cleanHeaders[key] = "[REDACTED_SIZE_LIMIT]";
      } else {
        cleanHeaders[key] = headerValue;
      }
    }
  }

  return cleanHeaders;
}

async function opaAuth(r) {
  try {
    if (r.variables.original_method == "OPTIONS") {
      return r.return(204);
    }

    const body = {
      input: {
        method: r.variables.original_method,
        headers: filterHeaders(r),
        query: qs.parse(r.variables.original_args),
        domain: r.variables.domain,
      },
    };

    const response = await r.subrequest("/opa", {
      body: JSON.stringify(body),
      method: "POST",
    });

    if (response.status > 500) {
      return r.return(response.status);
    }

    const opaResult = JSON.parse(response.responseText).result;
    if (!opaResult.allowed) {
      r.error(opaResult.reason);
      const returnCode = opaResult.reason.includes("no token supplied")
        ? 401
        : 403;

      r.variables.opa_result = "false";
      r.variables.opa_reason = opaResult.reason;
      return r.return(returnCode);
    }
    r.variables.opa_result = "true";

    r.variables.opa_reason = "";

    r.return(204);
  } catch (error) {
    r.error(error);
    r.variables.opa_result = "error";
    r.return(500);
  }
}

function jwt(data) {
  if (data) {
    var parts = data
      .split(".")
      .slice(0, 2)
      .map((v) => Buffer.from(v, "base64url").toString())
      .map(JSON.parse);
    return { headers: parts[0], payload: parts[1] };
  } else {
    return;
  }
}

function jwtPayloadSub(r) {
  try {
    let token;
    if (r.args["token"]) token = jwt(r.args["token"]);
    else if (r.headersIn["x-api-key"]) token = jwt(r.headersIn["x-api-key"]);
    else return "";

    return token.payload.sub;
  } catch (error) {
    return "";
  }
}

export default { opaAuth, jwtPayloadSub };
