-- Simulación de esquema SQL para visualizar la base de datos local Hive (NoSQL key-value)
-- Importante: Esto NO es SQL real ejecutado por la app. Hive almacena pares clave→valor.
-- Este archivo describe en formato SQL-like cómo luce la información guardada.
-- Caja(s) actuales detectadas en el proyecto: userBox
-- Claves habituales:
--   - 'user:<correo>' → objeto User serializado (Map)
--   - 'currentUserEmail' → puntero a la sesión iniciada
-- No se detecta una 'settingsBox' separada; las configuraciones (tema, color, fuente, etc.)
-- se guardan dentro del objeto User en la misma caja 'userBox'.

/*==========================================================================
  ESQUEMA
  ==========================================================================
  Nota: Los tipos y restricciones son ilustrativos (SQL Server-like).
  En Hive, todos los datos se serializan como Map/dynamic.
==========================================================================*/

-- Tabla simulada para la caja 'userBox': Usuarios + ajustes por usuario
CREATE TABLE [dbo].[Users] (
  [id]            NVARCHAR(255)  NOT NULL,      -- Sugerido: 'user:<correo>' (clave Hive)
  [nombre]        NVARCHAR(100)  NOT NULL,
  [apellido]      NVARCHAR(100)  NOT NULL,
  [genero]        NVARCHAR(50)   NULL,
  [edad]          INT            NULL,
  [altura]        FLOAT          NULL,          -- cm
  [peso]          FLOAT          NULL,          -- kg
  [correo]        NVARCHAR(255)  NOT NULL,      -- único
  [contraseña]    NVARCHAR(255)  NOT NULL,
  -- Ajustes guardados dentro del usuario (no hay caja settings separada)
  [brightness]    NVARCHAR(10)   NULL  CHECK ([brightness] IN ('light','dark')),
  [seedColor]     INT            NULL,          -- ARGB (por ejemplo 0xFF80CBC4); se almacena como entero
  [fontFamily]    NVARCHAR(50)   NULL,          -- null → sistema; valores típicos: 'serif'
  [followLocation] BIT           NULL,          -- true/false
  [createdAt]     DATETIME       NULL DEFAULT (GETDATE()),
  [updatedAt]     DATETIME       NULL DEFAULT (GETDATE()),
  CONSTRAINT [PK_Users] PRIMARY KEY ([id]),
  CONSTRAINT [UQ_Users_Correo] UNIQUE ([correo])
);

-- Índices recomendados
CREATE UNIQUE INDEX [IX_Users_Correo] ON [dbo].[Users] ([correo]);
CREATE INDEX [IX_Users_Brightness] ON [dbo].[Users] ([brightness]);

-- Punteros de sesión simulados (mapean claves Hive tipo 'currentUserEmail')
CREATE TABLE [dbo].[SessionPointers] (
  [key]        NVARCHAR(64)   NOT NULL,     -- e.g. 'currentUserEmail'
  [value]      NVARCHAR(255)  NULL,         -- e.g. correo del usuario activo
  [updatedAt]  DATETIME       NULL DEFAULT (GETDATE()),
  CONSTRAINT [PK_SessionPointers] PRIMARY KEY ([key])
);

/*==========================================================================
  VISTAS (opcionales de visualización)
==========================================================================*/
-- Vista que expone solo los ajustes de apariencia por usuario
CREATE VIEW [dbo].[UserSettingsView]
AS
SELECT
  [correo],
  [brightness],
  [seedColor],     -- ARGB entero (ej. 0xFF80CBC4)
  [fontFamily],
  [followLocation]
FROM [dbo].[Users];

/*==========================================================================
  DATOS DE EJEMPLO (INSERTs ficticios)
==========================================================================*/
-- Usuario 1 con tema oscuro y color semilla #FF80CBC4
INSERT INTO [dbo].[Users] (
  [id], [nombre], [apellido], [genero], [edad], [altura], [peso],
  [correo], [contraseña],
  [brightness], [seedColor], [fontFamily], [followLocation],
  [createdAt], [updatedAt]
) VALUES (
  'user:alice@example.com', 'Alice', 'Pérez', 'Femenino', 28, 165.0, 60.5,
  'alice@example.com', 'Secreta123',
  'dark', 0xFF80CBC4, 'serif', 1,
  GETDATE(), GETDATE()
);

-- Usuario 2 con tema claro y color semilla #FFE53935
INSERT INTO [dbo].[Users] (
  [id], [nombre], [apellido], [genero], [edad], [altura], [peso],
  [correo], [contraseña],
  [brightness], [seedColor], [fontFamily], [followLocation],
  [createdAt], [updatedAt]
) VALUES (
  'user:bob@example.com', 'Bob', 'García', 'Masculino', 34, 178.0, 82.3,
  'bob@example.com', 'ClaveFuerte!',
  'light', 0xFFE53935, NULL, 0,
  GETDATE(), GETDATE()
);

-- Puntero de sesión actual (equivale a Hive key 'currentUserEmail')
INSERT INTO [dbo].[SessionPointers] ([key], [value], [updatedAt])
VALUES ('currentUserEmail', 'alice@example.com', GETDATE());

/*==========================================================================
  NOTAS
  - Hive es NoSQL y guarda datos como clave→valor (Map). Este diseño SQL
    es una representación conceptual para herramientas tipo SSMS.
  - En el proyecto actual, las configuraciones de apariencia (tema, color,
    fuente, seguir ubicación) se almacenan dentro del objeto del usuario,
    en la caja 'userBox'. No hay una caja 'settingsBox' separada.
  - Las claves reales en Hive:
      * 'user:<correo>' → fila de [dbo].[Users] (id = 'user:<correo>')
      * 'currentUserEmail' → puntero en [dbo].[SessionPointers]
==========================================================================*/
