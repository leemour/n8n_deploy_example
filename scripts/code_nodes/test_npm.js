const zod = require('zod');
const _ = require('lodash');
const Papa = require('papaparse');

// Quick sanity check — return versions
return [{
  json: {
    zod: zod.z?.version ?? 'loaded',
    lodash: _.VERSION,
    papaparse: Papa.PAPA_VERSION,
  }
}];

// If it returns the versions/'loaded' without throwing, the package is accessible.

// For packages that don't expose a version property, just check they load without error:

const cheerio = require('cheerio');
const handlebars = require('handlebars');
const { v4: uuidv4 } = require('uuid');
return [{ json: { uuid: uuidv4(), handlebars: !!handlebars.compile } }];

const sharp = require('sharp');
const QRCode = require('qrcode');
const tiktoken = require('tiktoken');
const ExcelJS = require('exceljs');
const PDFLib = require('pdf-lib');
const AdmZip = require('adm-zip');
const FormData = require('form-data');
const libphonenumber = require('libphonenumber-js');
const turndown = require('turndown');
const sanitizeHtml = require('sanitize-html');
const jsonwebtoken = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const fastXmlParser = require('fast-xml-parser');

return [{
  json: {
    sharp: typeof sharp === 'function' || typeof sharp === 'object',
    qrcode: !!QRCode.toDataURL,
    tiktoken: typeof tiktoken.encoding_for_model === 'function',
    exceljs: typeof ExcelJS.Workbook === 'function',
    pdfLib: typeof PDFLib.PDFDocument === 'function',
    admZip: typeof AdmZip === 'function',
    formData: typeof FormData === 'function',
    libphonenumber: !!libphonenumber.parsePhoneNumber,
    turndown: typeof turndown === 'function' || typeof turndown === 'object',
    sanitizeHtml: typeof sanitizeHtml === 'function',
    jsonwebtoken: typeof jsonwebtoken.sign === 'function',
    bcrypt: typeof bcrypt.hash === 'function',
    fastXmlParser: typeof fastXmlParser.parse === 'function'
  }
}];
