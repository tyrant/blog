const defaultTheme = require('tailwindcss/defaultTheme');

module.exports = {
  content: [
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*'
  ],
  theme: {
    screens: {
      'xs': '350px',
      ...defaultTheme.screens,
    },
    extend: {},
  },
  plugins: [],
}
