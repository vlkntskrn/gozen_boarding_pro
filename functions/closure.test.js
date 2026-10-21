const {test} = require("node:test");
const assert = require("node:assert/strict");
const {validateFiles} = require("./closure");
const file = (name) => ({name, base64: Buffer.from("PK1234").toString("base64")});
test("BA selects only 0012; other carriers only 0011", () => {
  const ba = [file("OPR-FRM-0098_BA123.docx"), file("OPR-FRM-0012_BA123.xlsx")];
  assert.equal(validateFiles({flightCode: "BA123"}, ba).attachments.length, 2);
  assert.throws(() => validateFiles({flightCode: "LS123"}, ba));
  const ls = [file("OPR-FRM-0098_LS123.docx"), file("OPR-FRM-0011_LS123.xlsx")];
  assert.equal(validateFiles({flightCode: "LS123"}, ls).hash, validateFiles({flightCode: "LS123"}, ls).hash);
  assert.throws(() => validateFiles({flightCode: "BA123"}, ls));
});
test("reject missing, duplicate, corrupt and oversized attachments", () => {
  const f = {flightCode: "LS123"};
  assert.throws(() => validateFiles(f, []));
  assert.throws(() => validateFiles(f, [file("OPR-FRM-0098_LS123.docx"), file("OPR-FRM-0098_LS123.docx")]));
  assert.throws(() => validateFiles(f, [{name: "OPR-FRM-0098_LS123.docx", base64: "bad!"}, file("OPR-FRM-0011_LS123.xlsx")]));
  assert.throws(() => validateFiles(f, [{name: "OPR-FRM-0098_LS123.docx", base64: Buffer.concat([Buffer.from("PK"), Buffer.alloc(6 * 1024 * 1024)]).toString("base64")}, file("OPR-FRM-0011_LS123.xlsx")]));
});
