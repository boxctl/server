import { createServer } from "http";

const PORT = process.env.PORT;

createServer((req, res) => {
    res.writeHead(200, { "Content-Type": "text/html" });
    res.end("ok");
}).listen(PORT, () => {
    console.log(`Listening on ${PORT}`);
});
