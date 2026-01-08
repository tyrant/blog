const defaultTheme = require('tailwindcss/defaultTheme');

module.exports = {
  darkMode: 'class',
  content: [
    './app/**/*.html.erb',
    './app/components/*.{js,ts,rb}',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.{js,ts}',
    './app/views/**/*.{erb,html}',
    './public/*.html',
  ],
  theme: {
    screens: {
      'xs': '400px',
      '3xl': '2000px',
      ...defaultTheme.screens,
    },
    extend: {
      fontFamily: {
        'chuck-five': ['Chuck Five'],
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/typography'),
  ],
}
