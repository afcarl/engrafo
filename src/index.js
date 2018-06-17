const fs = require("fs-extra");
const jsdom = require("jsdom");
const path = require("path");

const io = require("./io");
const latexml = require("./latexml");
const math = require("./math");
const postprocessors = require("./postprocessor");

// Run postprocessing against a string of HTML
exports.postprocess = (htmlString, options) => {
  var dom = jsdom.jsdom(htmlString, {
    features: { ProcessExternalResources: false, FetchExternalResources: false }
  });

  // Run all processing on document.
  postprocessors.css(dom, options);
  postprocessors.footer(dom);
  postprocessors.links(dom);
  postprocessors.math(dom);

  return jsdom.serializeDocument(dom);
};

// Do all processing on the file that LaTeXML produces
async function processHTML(htmlPath, options) {
  let htmlString = await fs.readFile(htmlPath, "utf8");
  htmlString = exports.postprocess(htmlString, options);
  htmlString = await math.renderMath(htmlString);
  await fs.writeFile(htmlPath, htmlString);
}

// Render and postprocess a LaTeX file into outputDir (created if does not
// exist). Calls callback with an error on failure or a path to an HTML file
// on success.
async function render({ input, output, postProcessing, externalCSS }) {
  if (postProcessing === undefined) {
    postProcessing = true;
  }

  const inputDir = await io.prepareInputDirectory(input);
  const texPath = await io.pickLatexFile(inputDir);
  const outputDir = await io.prepareOutputDirectory(output);

  // If there is external CSS, don't let LaTeXML copy it to the output
  // directory - we will handle it ourselves
  const cssPath = externalCSS
    ? null
    : path.join(__dirname, "../dist/index.css");

  console.log(`Rendering tex file ${texPath} to ${outputDir}`);
  const htmlPath = await latexml.render({ texPath, outputDir, cssPath });

  await processHTML(htmlPath, { externalCSS });

  if (output.startsWith("s3://")) {
    await io.uploadOutputToS3(outputDir, output);
  }

  return htmlPath;
}

module.exports = {
  render: render
};
