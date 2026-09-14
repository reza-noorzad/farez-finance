@'

\# Farez Finance



A personal finance management application built with Flutter and Supabase.



🌐 \*\*Live Demo:\*\* https://farez-finance-demo.vercel.app



\## Overview



Farez Finance is a personal project designed to manage everyday financial processes in one structured application. The project combines account management, income and expense tracking, savings, debts, travel funds, budgeting and financial reporting.



The application was developed iteratively with AI-assisted development. I defined the requirements, financial logic and workflows, tested the results, identified problems and continuously improved the implementation.



\## Key Features



\- Account and balance management

\- Income and expense tracking

\- Dynamic expense categories

\- Monthly budgets

\- Savings goals and fund reservations

\- Transfers between accounts and funds

\- Debt and repayment management

\- Travel plans and travel funds

\- Monthly and annual financial reports

\- Product and expense analytics

\- PDF report generation

\- Receipt JSON parsing

\- User authentication and family-based data structure



\## Tech Stack



\- Flutter / Dart

\- Supabase

\- PostgreSQL

\- Row Level Security (RLS)

\- Vercel

\- Git / GitHub



\## System \& Data Logic



A major focus of the project is consistent financial data handling. Transactions affect the appropriate accounts, transfers do not create artificial income, and financial operations are structured to avoid double counting.



The Supabase backend uses relational tables and Row Level Security policies to separate and protect user data.



\## AI-Assisted Development



AI tools, especially ChatGPT, were used as development support for implementation, debugging and iterative improvement.



My role included:



\- defining requirements and workflows

\- designing financial and system logic

\- evaluating proposed implementations

\- testing features and edge cases

\- identifying errors and inconsistencies

\- refining prompts and requirements

\- integrating and validating solutions



This project helped me develop practical experience in AI-assisted software development and in translating real-world requirements into working digital processes.



\## Demo \& Privacy



The public demo uses a dedicated Supabase demo environment.



No personal financial data or production database content is included in this repository or the demo environment.



➡️ \*\*Try the live application:\*\* https://farez-finance-demo.vercel.app



\## Run Locally



Requirements:



\- Flutter SDK

\- Chrome or another supported Flutter target



```bash

flutter pub get

flutter run -d chrome

