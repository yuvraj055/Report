const express = require('express');
const { exec } = require('child_process');
const path = require('path');
const fs = require('fs');
const pdf = require('html-pdf');
const app = express();
const port = 3000;

// Serve static files (CSS, JS)
app.use(express.static(__dirname));

// Serve the front-end HTML
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

// Function to parse audit results
function parseAuditResults(stdout) {
    const sections = stdout.split('===');
    const auditData = {};

    sections.forEach(section => {
        const lines = section.trim().split('\n');
        if (lines.length > 0) {
            const title = lines[0].trim();
            const content = lines.slice(1).join('\n').trim();
            if (title) {
                auditData[title] = content;
            }
        }
    });

    return auditData;
}

// Endpoint to trigger the audit and send data to the frontend
app.get('/run-audit', (req, res) => {
    const scriptPath = path.join(__dirname, 'audit.ps1');

    exec(`powershell.exe -ExecutionPolicy Bypass -File "${scriptPath}"`, (error, stdout, stderr) => {
        if (error || stderr) {
            res.status(500).send(`Error running audit: ${error?.message || stderr}`);
            return;
        }

        const auditData = parseAuditResults(stdout);
        res.json(auditData); // Send the parsed data to the frontend
    });
});

// Function to generate HTML for the PDF
function generateAuditReportHtml(auditData) {
    let htmlContent = `
    <html>
    <head>
        <style>
            body { font-family: Arial, sans-serif; }
            h1 { text-align: center; }
            pre { background: #f4f4f4; padding: 10px; border-radius: 5px; }
        </style>
    </head>
    <body>
        <h1>System Security Audit Report</h1>
    `;

    for (const section in auditData) {
        htmlContent += `
        <h2>${section}</h2>
        <pre>${auditData[section] || 'No data available'}</pre>
        `;
    }

    htmlContent += `</body></html>`;
    return htmlContent;
}

// Endpoint to download the report as PDF
app.get('/download-pdf', (req, res) => {
    const scriptPath = path.join(__dirname, 'audit.ps1');

    exec(`powershell.exe -ExecutionPolicy Bypass -File "${scriptPath}"`, (error, stdout, stderr) => {
        if (error || stderr) {
            res.status(500).send(`Error generating PDF: ${error?.message || stderr}`);
            return;
        }

        const auditData = parseAuditResults(stdout);
        const auditReportHtml = generateAuditReportHtml(auditData);

        pdf.create(auditReportHtml).toStream((err, stream) => {
            if (err) return res.status(500).send('Error generating PDF');
            res.setHeader('Content-Type', 'application/pdf');
            res.setHeader('Content-Disposition', 'attachment; filename="SecurityAuditReport.pdf"');
            stream.pipe(res);
        });
    });
});

// Start the server
app.listen(port, () => {
    console.log(`Audit app listening at http://localhost:${port}`);
});
