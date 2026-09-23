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

function buildOpaBody(r) {
  return JSON.stringify({
    input: {
      method: r.variables.original_method,
      headers: filterHeaders(r),
      query: qs.parse(r.variables.original_args),
      domain: r.variables.domain,
    },
  });
}

// Normalizes a denied OPA result's `reason` (string) or `reasons` (array) into one message.
function opaDenyReason(opaResult) {
  if (opaResult.reason) {
    return opaResult.reason;
  }
  if (opaResult.reasons) {
    return opaResult.reasons.join(", ");
  }
  return "Access denied - no reason provided";
}

// Runs the OPA check and returns a decision without writing any response.
// The caller owns how the outcome is surfaced (nginx variables vs. response
// headers) and whether the request terminates, so this can back both the
// standalone opaAuth handler and gateways that chain further subrequests.
// Returns one of:
//   { kind: "options",       allowed: true,  code: 204 }         // no OPA call
//   { kind: "upstreamError", allowed: false, code: <5xx> }       // OPA >500
//   { kind: "deny",          allowed: false, code: 401|403, reason }
//   { kind: "allow",         allowed: true,  code: 204 }
// Throws on subrequest/parse failure — the caller's catch owns the 500.
async function opaDecide(r) {
  if (r.variables.original_method == "OPTIONS") {
    return { kind: "options", allowed: true, code: 204 };
  }

  const response = await r.subrequest("/opa", {
    body: buildOpaBody(r),
    method: "POST",
  });

  if (response.status > 500) {
    return { kind: "upstreamError", allowed: false, code: response.status };
  }

  const opaResult = JSON.parse(response.responseText).result;
  if (!opaResult.allowed) {
    const reason = opaDenyReason(opaResult);
    const code = reason.includes("no token supplied") ? 401 : 403;
    return { kind: "deny", allowed: false, code, reason };
  }

  return { kind: "allow", allowed: true, code: 204 };
}

async function opaAuth(r) {
  try {
    const decision = await opaDecide(r);
    if (decision.kind === "deny") {
      r.error(decision.reason);
      r.variables.opa_result = "false";
      r.variables.opa_reason = decision.reason;
    } else if (decision.kind === "allow") {
      r.variables.opa_result = "true";
      r.variables.opa_reason = "";
    }
    return r.return(decision.code);
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

export default { opaAuth, opaDecide, jwtPayloadSub, buildOpaBody, opaDenyReason };
