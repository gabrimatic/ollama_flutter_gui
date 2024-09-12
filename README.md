# Ollama Flutter GUI

## Overview

Ollama Flutter GUI is a modern, responsive web application that leverages the power of Ollama's offline language models to provide an interactive chat experience. Built with Flutter, this application offers a sleek, material design-inspired interface for interacting with various AI models locally.

## Features

- **Responsive Web Design**: Optimized for various screen sizes while maintaining a maximum width for better readability.
- **Multiple Model Support**: Easily switch between different Ollama models by modifying a single line of code.
- **File Upload**: Ability to upload and process multiple files within the chat interface.
- **Modern UI**: Utilizes Material Design 3 for a fresh, contemporary look.
- **Offline Functionality**: Leverages Ollama's offline models for privacy and speed.
- **Real-time Responses**: Instant AI-generated responses to user inputs.

## Technical Stack

- **Frontend**: Flutter Web
- **State Management**: Riverpod
- **Backend Integration**: HTTP requests to local Ollama API
- **File Handling**: file_picker package for multi-file selection

## Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK (latest stable version)
- Ollama installed and running locally
- A modern web browser (Chrome, Firefox, Safari, or Edge)

## Setup and Installation

1. **Clone the Repository**
   ```
   git clone https://github.com/gabrimatic/ollama_flutter_gui.git
   cd ollama_flutter_gui
   ```

2. **Install Dependencies**
   ```
   flutter pub get
   ```

3. **Configure Ollama**
   Ensure Ollama is installed and running on your local machine. The default API endpoint is set to `http://localhost:11434/api/generate`. Modify this in `chat_state.dart` if your setup differs.

4. **Run the Application**
   ```
   flutter run -d chrome
   ```

## Usage

1. **Starting a Chat**: Type your message in the input field at the bottom of the screen and press the send button or hit enter.

2. **Uploading Files**: Click the attachment icon to select one or more files. The file names will be sent to the AI model for processing.

3. **Changing AI Models**: To use a different Ollama model, modify the `model` field in the POST request body in `chat_state.dart`. For example, change `'model': 'llama3.1'` to `'model': 'gpt4'` or any other model you have installed in Ollama.

4. **Viewing Responses**: AI-generated responses will appear in the chat interface, distinguished from user messages by color and alignment.

## Project Structure

- `lib/`
  - `main.dart`: Entry point of the application
  - `chat_screen.dart`: Main chat interface
  - `chat_state.dart`: State management and API interactions
  - `chat_message.dart`: Chat message model and widget

## Customization

- **Colors**: Modify the color scheme in `main.dart` by changing the `seedColor` in `ColorScheme.fromSeed()`.
- **API Endpoint**: Update the API URL in `chat_state.dart` if you're using a different address for Ollama.
- **Max Width**: Adjust the `maxWidth` constraint in `chat_screen.dart` to change the application's maximum width.
- **AI Model**: Change the model in `chat_state.dart` by modifying the `model` field in the POST request body.

## Contributing

Contributions to Ollama Flutter GUI are welcome! Please feel free to submit pull requests, create issues or spread the word.

## License

MIT License

## Acknowledgements

- Ollama team for providing powerful offline language models
- Flutter and Dart teams for the excellent framework and language
- Contributors and users of this project

---

For more information on Flutter development, please refer to the [Flutter documentation](https://flutter.dev/docs).

For details on Ollama and its models, visit the [Ollama official website](https://ollama.ai/).

## Developer
By [Hossein Yousefpour](https://gabrimatic.info "Hossein Yousefpour")

&copy; All rights reserved.

## Donate
<a href="https://www.buymeacoffee.com/gabrimatic" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Book" style="height: 41px !important;width: 174px !important;box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;-webkit-box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;" ></a>