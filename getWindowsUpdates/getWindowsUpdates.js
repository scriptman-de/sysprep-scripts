const fs = require("fs");
const path = require("path");
const parseString = require("xml2js").parseString;

if (!process.argv[3]) {
  // windows build number must be given
  console.log("please provide windows build number as third argument!");
  process.exit(1);
}

fs.readFile(process.argv[2], "utf8", (err, data) => {
  if (err) {
    process.exit(2);
  }
  parseString(data, (err, res) => {
    if (err) {
      process.exit(3);
    }
    // const xml = JSON.stringify(res);
    // fs.writeFileSync(path.join(__dirname, "xmloutput.json"), xml);

    let updatesList = res.hotfixlist.updates[0].update;
    let filteredUpdatesList = [];
    for (const update of updatesList) {
      let cat = update.category[0];
      if (cat == "General/" + process.argv[3]) {
        filteredUpdatesList.push({
          name: update.name[0],
          description: update.description[0]
        });
      }
    }

    // console.log(filteredUpdatesList);
    let SSUlist = [],
      normalList = [];
    // iteration to filter list
    filteredUpdatesList.forEach(item => {
      if (item.description.includes("Servicing Stack Update")) {
        SSUlist.push(item);
      } else {
        normalList.push(item);
      }
    });

    let _return = [...SSUlist, ...normalList].map(item => item.name).join(" ");
    // console.error(_return);
    console.log(_return);
  });
});
