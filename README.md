# logtool

`logtool` is a MATLAB script designed to detect logging intervals from a cetacean tag record. It was built to automatically identify extended periods of resting at the surface from depth data.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)
- [Contact](#contact)

## Installation

To get started with `logtool`, simply clone this repository or download the script directly.

```bash
git clone https://github.com/yourusername/logtool.git
```
Make sure you have MATLAB installed (R202a or later is recommended). 

## Usage
To use logtool, pass in your tag data as an input. The script will analyze the input and return time intervals where logging is detected.

```matlab
LogData = logtool();
```

### Output
`LogData` – a table containing one row per logging period identified and the following columns:

 - `ID` - Tag record ID
 - `Species` - Two-letter species code
 - `Location` - Geographic location of tag deployment
 - `Tag Type` - Tag type as in D2, D3, D4, CATS, etc.
 - `PHz` - Sampling rate of depth
 - `Record Duration (Seconds)` - Duration of full tag deployment in seconds
 - `StartI` - Start index of logging interval within the record
 - `EndI` - End index of logging interval within the record
 - `Start Logging (Seconds)` - Start time of logging interval within the record in seconds
 - `End Logging (Seconds)` - End time of logging interval within the record in seconds
 - `Logging Duration (Seconds)` - Duration of logging in seconds
 - `Date Analyzed` - Date that logtool() was run on this record and data saved
 - `Creator` - Name of data analyzer

## Contributing
Contributions are welcome! Please open an issue or submit a pull request if you'd like to contribute improvements or bug fixes.

## License
This project is licensed under the MIT License.

## Contact
For questions or support, contact [ashleyblawas@stanford.edu] or open an issue on GitHub.
