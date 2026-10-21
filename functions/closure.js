const {createHash} = require("node:crypto");

// Pure request validation. Never accept client-selected recipients or a form
// belonging to another carrier. Payload exists in memory for SMTP only.
exports.validateFiles = (flight, files) => {
  if (!Array.isArray(files) || files.length !== 2) throw new Error("Two forms required");
  const form = /^(BA|BAW)\d/.test(flight.flightCode) ? "OPR-FRM-0012" : "OPR-FRM-0011";
  const expected = [`OPR-FRM-0098_${flight.flightCode}.docx`, `${form}_${flight.flightCode}.xlsx`];
  let size = 0;
  const attachments = expected.map((filename) => {
    const matches = files.filter((f) => f && f.name === filename);
    if (matches.length !== 1 || typeof matches[0].base64 !== "string" ||
        !/^[A-Za-z0-9+/]*={0,2}$/.test(matches[0].base64)) throw new Error("Wrong form");
    const content = Buffer.from(matches[0].base64, "base64");
    if (content.length < 4 || content[0] !== 80 || content[1] !== 75) throw new Error("Invalid Office file");
    size += content.length;
    return {filename, content};
  });
  if (size > 5 * 1024 * 1024) throw new Error("Report too large");
  const hash = createHash("sha256");
  for (const a of attachments) hash.update(a.filename).update(a.content);
  return {attachments, hash: hash.digest("hex")};
};
