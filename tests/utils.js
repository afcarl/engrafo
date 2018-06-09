const util = require("util");
const engrafo = require("../src");
const readFile = util.promisify(require("fs").readFile);
const { configureToMatchImageSnapshot } = require("jest-image-snapshot");
const jsdom = require("jsdom");
const path = require("path");
const tmp = require("tmp-promise");

const toMatchImageSnapshot = configureToMatchImageSnapshot({
  customDiffConfig: {
    threshold: 0.05
  },
  noColors: true
});
expect.extend({ toMatchImageSnapshot });

exports.renderToDom = async input => {
  input = path.join(__dirname, input);

  const tmpDir = await tmp.dir({ unsafeCleanup: true });

  const htmlPath = await engrafo.render({ input: input, output: tmpDir.path });
  const htmlString = await readFile(htmlPath, "utf-8");
  const document = jsdom.jsdom(htmlString, {
    features: {
      ProcessExternalResources: false,
      FetchExternalResources: false
    }
  });
  return { htmlPath, document };
};

exports.expectToMatchSnapshot = async inputPath => {
  const { htmlPath, document } = await exports.renderToDom(inputPath);

  removeDescendants(document.body, "script");
  removeDescendants(document.body, "style");
  // This includes the time generated, so is not deterministic
  removeDescendants(document.body, ".ltx_page_logo");
  expect(document.body).toMatchSnapshot();

  const localPage = await browser.newPage();
  try {
    await localPage.goto(`file://${htmlPath}`, { waitUntil: "networkidle0" });
    const screenshot = await localPage.screenshot({
      fullPage: true
    });
    expect(screenshot).toMatchImageSnapshot();
  } finally {
    localPage.close();
  }
};

function removeDescendants(element, selector) {
  Array.from(element.querySelectorAll(selector)).forEach(el => {
    el.parentNode.removeChild(el);
  });
}
