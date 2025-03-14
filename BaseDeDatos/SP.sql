--Registrar un usuario nuevo
CREATE OR ALTER PROCEDURE SP_REGISTRAR_USUARIO
    @NOMBRE VARCHAR(100),
    @CORREO_ELECTRONICO NVARCHAR(255),
    @CONTRASENA NVARCHAR(255),
    @FECHA_NACIMIENTO DATE,
    @FOTO_PERFIL VARBINARY(MAX) = NULL,
    @DIRECCION VARCHAR(255) = NULL,
    @ID_TIPO_USUARIO INT,
	@ID_RETURN INT OUTPUT,
	@ERROR_ID INT OUTPUT,
	@ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    DECLARE @CODIGO VARCHAR(6) = NULL;
    DECLARE @EXISTE INT;
    DECLARE @ID_USUARIO INT;
    
    BEGIN TRY
        BEGIN TRANSACTION;

		IF EXISTS ( SELECT * FROM [dbo].[USUARIO] WHERE [CORREO_ELECTRONICO] = @CORREO_ELECTRONICO)
        BEGIN
		SET @ID_RETURN = -1;
		SET @ERROR_ID  = 1;
		SET @ERROR_DESCRIPTION ='Correo existente';
			
	     END
	     ELSE 
		 BEGIN
		 -- Si el usuario es paciente (suponiendo que ID_TIPO_USUARIO = 1 es paciente)
			IF @ID_TIPO_USUARIO = 1
			BEGIN
				WHILE 1 = 1
				BEGIN
				  SET @EXISTE = 0;
					-- Generar un código alfanumérico de 6 caracteres
					SET @CODIGO = LEFT(NEWID(), 6);
                
					-- Verificar que el código no exista
					SELECT @EXISTE = COUNT(*) FROM USUARIO WHERE CODIGO = @CODIGO;
                
					-- Si no existe, salir del bucle
					IF @EXISTE = 0 BREAK;
				END
			END

        
			-- Insertar el nuevo usuario
			INSERT INTO USUARIO (NOMBRE, CORREO_ELECTRONICO, CONTRASENA, FECHA_NACIMIENTO, FOTO_PERFIL, CODIGO, DIRECCION, ID_TIPO_USUARIO)
			VALUES (@NOMBRE, @CORREO_ELECTRONICO, @CONTRASENA, @FECHA_NACIMIENTO, @FOTO_PERFIL, @CODIGO, @DIRECCION, @ID_TIPO_USUARIO);
		 END 

        SET @ID_RETURN = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ID_RETURN = -1;
		SET @ERROR_ID  = ERROR_NUMBER();
		SET @ERROR_DESCRIPTION =ERROR_MESSAGE();
    END CATCH
END;
GO

--Actualizar foto de perfil
CREATE OR ALTER PROCEDURE SP_ACTUALIZAR_FOTO_PERFIL
    @ID_USUARIO INT,
    @FOTO_PERFIL VARBINARY(MAX),
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Verificar si el usuario existe
        IF NOT EXISTS (SELECT 1 FROM [dbo].[USUARIO] WHERE [ID_USUARIO] = @ID_USUARIO)
        BEGIN
            SET @ERROR_ID = 2;
            SET @ERROR_DESCRIPTION = 'Usuario no encontrado';
        END
        ELSE
        BEGIN
            -- Actualizar la foto de perfil
            UPDATE USUARIO
            SET FOTO_PERFIL = @FOTO_PERFIL
            WHERE ID_USUARIO = @ID_USUARIO;
        END

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
GO

--Insertar un ping 
CREATE OR ALTER PROCEDURE SP_INSERTAR_PING
    @ID_USUARIO INT,
    @CODIGO VARCHAR(6),
    @ID_RETURN INT OUTPUT,
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Verificar que el usuario exista y sea de tipo paciente (ID_TIPO_USUARIO = 1)
        IF NOT EXISTS (SELECT 1 FROM [dbo].[USUARIO] WHERE [ID_USUARIO] = @ID_USUARIO AND ID_TIPO_USUARIO = 1)
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 3;
            SET @ERROR_DESCRIPTION = 'El usuario no existe o no es un paciente';
            ROLLBACK TRANSACTION;
            RETURN;
        END
                -- Verificar si el usuario ya tiene un PING activo
        IF EXISTS (SELECT 1 FROM PING WHERE ID_USUARIO = @ID_USUARIO AND ESTADO = 1)
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 5;
            SET @ERROR_DESCRIPTION = 'El usuario ya tiene un PIN activo';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
                -- Verificar si el usuario ya tiene un PING activo
        IF EXISTS (SELECT 1 FROM PING WHERE ID_USUARIO = @ID_USUARIO AND ESTADO = 1)
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 5;
            SET @ERROR_DESCRIPTION = 'El usuario ya tiene un PIN activo';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        

        -- Verificar que el código no sea nulo
        IF @CODIGO IS NULL OR LEN(@CODIGO) <> 6 OR @CODIGO LIKE '%[^0-9]%'
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 4;
            SET @ERROR_DESCRIPTION = 'El PIN debe contener exactamente 6 dígitos numéricos';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Insertar el nuevo ping
        INSERT INTO PING (CODIGO, FECHA, ESTADO, ID_USUARIO)
        VALUES (@CODIGO, GETDATE(), 1, @ID_USUARIO);
        
        SET @ID_RETURN = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ID_RETURN = -1;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
GO

--Editar datos del usuario 
CREATE OR ALTER PROCEDURE SP_EDITAR_USUARIO
    @ID_USUARIO INT,
    @NOMBRE VARCHAR(100),
    @FECHA_NACIMIENTO DATE,
    @DIRECCION VARCHAR(255),
    @PIN VARCHAR(6) = NULL,
    @ID_RETURN INT OUTPUT,
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    DECLARE @ID_TIPO_USUARIO INT;
    DECLARE @PIN_CORRECTO INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Verificar si el usuario existe y obtener su tipo
        SELECT @ID_TIPO_USUARIO = ID_TIPO_USUARIO FROM USUARIO WHERE ID_USUARIO = @ID_USUARIO;

        IF @ID_TIPO_USUARIO IS NULL
        BEGIN
            SET @ERROR_ID = 2;
            SET @ERROR_DESCRIPTION = 'El usuario no existe';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Si es paciente (tipo 1), verificar si tiene un PIN activo
        IF EXISTS(SELECT 1 FROM [dbo].[PING] WHERE [ID_USUARIO] = @ID_USUARIO AND [ESTADO] = 1) AND @ID_TIPO_USUARIO = 1 
        BEGIN
                SELECT @PIN_CORRECTO = COUNT(*) FROM PING WHERE ID_USUARIO = @ID_USUARIO AND CODIGO = @PIN AND ESTADO = 1;
                IF @PIN_CORRECTO = 0
                BEGIN
                    SET @ERROR_ID = 4;
                    SET @ERROR_DESCRIPTION = 'PIN incorrecto.';
                    ROLLBACK TRANSACTION;
                    RETURN;
                END
        END

        -- Actualizar los datos del usuario
        UPDATE USUARIO
        SET NOMBRE = @NOMBRE,
            FECHA_NACIMIENTO = @FECHA_NACIMIENTO,
            DIRECCION = @DIRECCION
        WHERE ID_USUARIO = @ID_USUARIO;

        COMMIT TRANSACTION;
        SET @ERROR_ID = NULL;
        SET @ERROR_DESCRIPTION = NULL;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
GO

--Modificar ping
CREATE OR ALTER PROCEDURE SP_MODIFICAR_PING
    @ID_USUARIO INT,
    @PIN_ACTUAL VARCHAR(6),
    @NUEVO_CODIGO VARCHAR(6),
    @ID_RETURN INT OUTPUT,
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS(SELECT 1 FROM [dbo].[PING]  WHERE ID_USUARIO = @ID_USUARIO  AND CODIGO = @PIN_ACTUAL AND ESTADO = 1)
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 2;
            SET @ERROR_DESCRIPTION = 'El PIN actual es incorrecto o no existe';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Validar que el nuevo código tenga 6 dígitos numéricos
        IF @NUEVO_CODIGO IS NULL OR LEN(@NUEVO_CODIGO) <> 6 OR @NUEVO_CODIGO LIKE '%[^0-9]%'
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 3;
            SET @ERROR_DESCRIPTION = 'El nuevo PIN debe contener exactamente 6 dígitos numéricos';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Actualizar el PIN activo
        UPDATE PING 
        SET ESTADO = 0
        WHERE ID_USUARIO = @ID_USUARIO AND CODIGO = @PIN_ACTUAL AND ESTADO = 1;

		INSERT INTO PING(CODIGO,FECHA,ESTADO,ID_USUARIO)
			VALUES(@NUEVO_CODIGO,GETDATE(),1,@ID_USUARIO)

		SET @ID_RETURN = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ID_RETURN = -1;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
GO

--Sp cambio de contra
CREATE OR ALTER PROCEDURE SP_CAMBIAR_CONTRASENA
    @ID_USUARIO INT,
    @CONTRASENA_ACTUAL VARCHAR(255),
    @NUEVA_CONTRASENA VARCHAR(255),
    @PIN VARCHAR(6) = NULL,
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @PIN_CORRECTO INT;
		DECLARE @ID_TIPO_USUARIO INT;

		        -- Si el usuario es un paciente (tipo 1), validar el PIN si tiene uno activo
		IF NOT EXISTS (SELECT 1 FROM [dbo].[USUARIO] WHERE @ID_USUARIO = [ID_USUARIO])
		BEGIN 
                SET @ERROR_ID = 4;
                SET @ERROR_DESCRIPTION = 'USUARIO NO EXISTE';
                ROLLBACK TRANSACTION;
                RETURN; 
		END
		ELSE
		BEGIN
			 IF EXISTS(SELECT 1 FROM [dbo].[PING] WHERE [ID_USUARIO] = @ID_USUARIO AND [ESTADO] = 1) 
			 BEGIN
                SELECT @PIN_CORRECTO = COUNT(*) FROM PING WHERE ID_USUARIO = @ID_USUARIO AND CODIGO = @PIN AND ESTADO = 1;
                IF @PIN_CORRECTO = 0
                BEGIN
                    SET @ERROR_ID = 4;
                    SET @ERROR_DESCRIPTION = 'PIN incorrecto.';
                    ROLLBACK TRANSACTION;
                    RETURN;
                END
			 END
		END

        -- Validar que la contraseña actual sea correcta
		IF NOT EXISTS (SELECT 1 FROM [dbo].[USUARIO] WHERE [CONTRASENA] = @CONTRASENA_ACTUAL AND [ID_USUARIO]= @ID_USUARIO)
        BEGIN
            SET @ERROR_ID = 2;
            SET @ERROR_DESCRIPTION = 'La contraseña actual es incorrecta';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Validar que la nueva contraseña no sea igual a la actual
        IF EXISTS (SELECT 1 FROM [dbo].[USUARIO] WHERE [CONTRASENA] = @NUEVA_CONTRASENA AND [ID_USUARIO]= @ID_USUARIO)
        BEGIN
            SET @ERROR_ID = 3;
            SET @ERROR_DESCRIPTION = 'La nueva contraseña no puede ser igual a la actual';
            ROLLBACK TRANSACTION;
            RETURN;
        END



        -- Actualizar la contraseña
        UPDATE USUARIO
        SET CONTRASENA = @NUEVA_CONTRASENA
        WHERE ID_USUARIO = @ID_USUARIO;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
GO

--SP RELACION ENTRE CUIDADOR PACIENTE 
CREATE OR ALTER PROCEDURE SP_RELACIONAR_PACIENTE_CUIDADOR
    @ID_USUARIO_CUIDADOR INT,
    @CODIGO_PACIENTE VARCHAR(6),
    @ID_RETURN INT OUTPUT,
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @ID_USUARIO_PACIENTE INT;

        -- Buscar el ID del paciente usando el código alfanumérico
        SELECT @ID_USUARIO_PACIENTE = ID_USUARIO FROM USUARIO WHERE CODIGO = @CODIGO_PACIENTE AND ID_TIPO_USUARIO = 1;

        -- Validar que el paciente exista
        IF @ID_USUARIO_PACIENTE IS NULL
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 1;
            SET @ERROR_DESCRIPTION = 'El código del paciente es incorrecto o no existe.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Validar que el cuidador exista
        IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE ID_USUARIO = @ID_USUARIO_CUIDADOR AND ID_TIPO_USUARIO = 2)
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 2;
            SET @ERROR_DESCRIPTION = 'El ID del cuidador no es válido.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Verificar si la relación ya existe
        IF EXISTS (SELECT 1 FROM CUIDADOR_PACIENTE WHERE ID_USUARIO_PACIENTE = @ID_USUARIO_PACIENTE AND ID_USUARIO_CUIDADOR = @ID_USUARIO_CUIDADOR AND FEC_FIN = NULL )
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 3;
            SET @ERROR_DESCRIPTION = 'La relación entre paciente y cuidador ya existe.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Insertar la relación en la tabla CUIDADOR_PACIENTE
        INSERT INTO CUIDADOR_PACIENTE (ID_USUARIO_CUIDADOR, ID_USUARIO_PACIENTE, FEC_INICIO)
        VALUES (@ID_USUARIO_CUIDADOR, @ID_USUARIO_PACIENTE, GETDATE());

        SET @ID_RETURN = SCOPE_IDENTITY();
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ID_RETURN = -1;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
GO

-- SP para eliminar la foto de perfil con validación de PING si es paciente (1)
CREATE OR ALTER PROCEDURE SP_EliminarFotoPerfil
    @ID_USUARIO INT,
    @CODIGO_PING VARCHAR(6) = NULL, -- Opcional, solo requerido si hay un ping activo
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @ES_PACIENTE BIT;
        DECLARE @PING_ACTIVO BIT = 0;

        -- Verificar si el usuario existe y obtener su tipo
        IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE ID_USUARIO = @ID_USUARIO)
        BEGIN
            SET @ERROR_ID = 1;
            SET @ERROR_DESCRIPTION = 'El usuario no existe.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

		IF EXISTS (SELECT 1 FROM [dbo].[PING] WHERE [ID_USUARIO] = @ID_USUARIO AND [ESTADO] = 1)
		BEGIN
			IF NOT EXISTS (SELECT 1 FROM [dbo].[PING] WHERE [ID_USUARIO] = @ID_USUARIO AND [CODIGO] = @CODIGO_PING)
			BEGIN
				SET @ERROR_ID = 2;
                SET @ERROR_DESCRIPTION = 'PIN incorrecto.';
                ROLLBACK TRANSACTION;
                RETURN;
			END
		END

        -- Eliminar la foto de perfil
        UPDATE USUARIO
        SET FOTO_PERFIL = NULL
        WHERE ID_USUARIO = @ID_USUARIO;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
GO

--SP ELIMINAR(PONER ESTADO EN 0) PING
CREATE OR ALTER PROCEDURE SP_EliminarPing
    @ID_USUARIO INT,
    @CODIGO_PING VARCHAR(6),
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Verificar si el usuario existe
        IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE ID_USUARIO = @ID_USUARIO)
        BEGIN
            SET @ERROR_ID = 1;
            SET @ERROR_DESCRIPTION = 'El usuario no existe.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Verificar si el usuario tiene un PING activo
        IF NOT EXISTS (SELECT 1 FROM PING WHERE ID_USUARIO = @ID_USUARIO AND ESTADO = 1)
        BEGIN
            SET @ERROR_ID = 2;
            SET @ERROR_DESCRIPTION = 'No hay un PING activo para este usuario.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Validar que el PIN proporcionado sea correcto
        IF NOT EXISTS (SELECT 1 FROM PING WHERE ID_USUARIO = @ID_USUARIO AND CODIGO = @CODIGO_PING AND ESTADO = 1)
        BEGIN
            SET @ERROR_ID = 3;
            SET @ERROR_DESCRIPTION = 'El PIN proporcionado es incorrecto.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Cambiar el estado del PING a 0 (desactivado)
        UPDATE PING
        SET ESTADO = 0
        WHERE ID_USUARIO = @ID_USUARIO AND CODIGO = @CODIGO_PING AND ESTADO = 1;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
GO

--SP Eliminar Relacion Cuidador-Paciente
CREATE OR ALTER PROCEDURE SP_TerminarRelacionCuidadorPaciente
    @ID_USUARIO_CUIDADOR INT,
    @ID_USUARIO_PACIENTE INT,
    @CODIGO_PING VARCHAR(6) = NULL, -- Opcional, solo requerido si el paciente termina la relación
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Verificar si el paciente existe y si es realmente un paciente
        IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE ID_USUARIO = @ID_USUARIO_PACIENTE AND ID_TIPO_USUARIO = 1)
        BEGIN
            SET @ERROR_ID = 1;
            SET @ERROR_DESCRIPTION = 'El usuario paciente no existe o no es un paciente.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Verificar si el cuidador existe
        IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE ID_USUARIO = @ID_USUARIO_CUIDADOR)
        BEGIN
            SET @ERROR_ID = 2;
            SET @ERROR_DESCRIPTION = 'El usuario cuidador no existe.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Verificar si la relación existe y no está terminada
        IF NOT EXISTS (SELECT 1 FROM CUIDADOR_PACIENTE WHERE ID_USUARIO_CUIDADOR = @ID_USUARIO_CUIDADOR AND ID_USUARIO_PACIENTE = @ID_USUARIO_PACIENTE AND FEC_FIN IS NULL)
        BEGIN
            SET @ERROR_ID = 3;
            SET @ERROR_DESCRIPTION = 'La relación entre el paciente y el cuidador no existe o ya fue terminada.';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Si el paciente está terminando la relación, validar su PING
        IF @CODIGO_PING != NULL AND EXISTS (SELECT 1 FROM PING WHERE ID_USUARIO = @ID_USUARIO_PACIENTE AND ESTADO = 1)
        BEGIN
            -- Validar que el PIN proporcionado sea correcto
            IF NOT EXISTS (SELECT 1 FROM PING WHERE ID_USUARIO = @ID_USUARIO_PACIENTE AND CODIGO = @CODIGO_PING AND ESTADO = 1)
            BEGIN
                SET @ERROR_ID = 4;
                SET @ERROR_DESCRIPTION = 'PIN incorrecto.';
                ROLLBACK TRANSACTION;
                RETURN;
            END
        END

        -- Actualizar la relación estableciendo la fecha de finalización
        UPDATE CUIDADOR_PACIENTE
        SET FEC_FIN = GETDATE()
        WHERE ID_USUARIO_CUIDADOR = @ID_USUARIO_CUIDADOR 
        AND ID_USUARIO_PACIENTE = @ID_USUARIO_PACIENTE 
        AND FEC_FIN IS NULL;

        SET @ERROR_ID = NULL;
        SET @ERROR_DESCRIPTION = NULL;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
GO


--PROPUESTA DE SPS PARA MANEJAR LOS EVENTOS

-- Procedimiento para agregar un evento sin asignar pacientes
CREATE OR ALTER PROCEDURE SP_AGREGAR_EVENTO
    @ID_CUIDADOR INT,
    @TITULO VARCHAR(255),
    @DESCRIPCION VARCHAR(255) = NULL,
    @FECHA_HORA DATETIME,
    @ID_PRIORIDAD INT,
    @ID_RETURN INT OUTPUT,
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que el cuidador existe
        IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE ID_USUARIO = @ID_CUIDADOR AND ID_TIPO_USUARIO = 2)
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 1;
            SET @ERROR_DESCRIPTION = 'El usuario no es un cuidador o no existe';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Validar que la prioridad sea válida
        IF NOT EXISTS (SELECT 1 FROM PRIORIDAD WHERE ID_PRIORIDAD = @ID_PRIORIDAD)
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 2;
            SET @ERROR_DESCRIPTION = 'La prioridad seleccionada no es válida';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Insertar evento
        INSERT INTO EVENTO (TITULO, DESCRIPCION, FECHA_HORA, ID_PRIORIDAD, ID_USUARIO)
        VALUES (@TITULO, @DESCRIPCION, @FECHA_HORA, @ID_PRIORIDAD, @ID_CUIDADOR);

        SET @ID_RETURN = SCOPE_IDENTITY(); -- Obtener el ID generado

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ID_RETURN = -1;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
GO

-- Procedimiento para asignar un paciente a un evento existente
CREATE OR ALTER PROCEDURE SP_ASIGNAR_PACIENTE_A_EVENTO
    @ID_EVENTO INT,
	@ID_CUIDADOR INT,
    @ID_PACIENTE INT,
    @ID_RETURN INT OUTPUT,
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que el evento existe y pertenece al cuidador
        IF NOT EXISTS (SELECT 1 FROM EVENTO WHERE ID_EVENTO = @ID_EVENTO AND ID_USUARIO = @ID_CUIDADOR)
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 1;
            SET @ERROR_DESCRIPTION = 'El evento no existe';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Validar que el paciente existe
        IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE ID_USUARIO = @ID_PACIENTE AND ID_TIPO_USUARIO = 1)
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 2;
            SET @ERROR_DESCRIPTION = 'El paciente no existe';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Insertar relación evento-usuario
        INSERT INTO EVENTO_USUARIO (ID_EVENTO, ID_USUARIO, ID_ESTADO)
        VALUES (@ID_EVENTO, @ID_PACIENTE, 1);

        SET @ID_RETURN = SCOPE_IDENTITY(); -- Obtener el ID generado

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ID_RETURN = -1;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
GO

-- Procedimiento para eliminar un paciente de un evento existente
CREATE OR ALTER PROCEDURE SP_ELIMINAR_PACIENTE_DE_EVENTO
    @ID_EVENTO INT,
    @ID_CUIDADOR INT,
    @ID_PACIENTE INT,
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que el evento existe y pertenece al cuidador
        IF NOT EXISTS (SELECT 1 FROM EVENTO WHERE ID_EVENTO = @ID_EVENTO AND ID_USUARIO = @ID_CUIDADOR)
        BEGIN
            SET @ERROR_ID = 1;
            SET @ERROR_DESCRIPTION = 'El evento no existe o no pertenece al cuidador';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Validar que el paciente está asignado al evento
        IF NOT EXISTS (SELECT 1 FROM EVENTO_USUARIO WHERE ID_EVENTO = @ID_EVENTO AND ID_USUARIO = @ID_PACIENTE)
        BEGIN
            SET @ERROR_ID = 2;
            SET @ERROR_DESCRIPTION = 'El paciente no está asociado a este evento';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Eliminar la relación del paciente con el evento
        DELETE FROM EVENTO_USUARIO
        WHERE ID_EVENTO = @ID_EVENTO 
        AND ID_USUARIO = @ID_PACIENTE;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
GO

--SP_MODIFICAR_EVENTO
CREATE OR ALTER PROCEDURE SP_MODIFICAR_EVENTO
    @ID_EVENTO INT,
    @ID_CUIDADOR INT,
    @TITULO VARCHAR(255),
    @DESCRIPCION VARCHAR(255) = NULL,
    @FECHA_HORA DATETIME,
    @ID_PRIORIDAD INT,
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que el evento existe y pertenece al cuidador
        IF NOT EXISTS (SELECT 1 FROM EVENTO WHERE ID_EVENTO = @ID_EVENTO AND ID_USUARIO = @ID_CUIDADOR)
        BEGIN
            SET @ERROR_ID = 1;
            SET @ERROR_DESCRIPTION = 'El evento no existe o no pertenece al cuidador';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Validar que la prioridad sea válida
        IF NOT EXISTS (SELECT 1 FROM PRIORIDAD WHERE ID_PRIORIDAD = @ID_PRIORIDAD)
        BEGIN
            SET @ERROR_ID = 2;
            SET @ERROR_DESCRIPTION = 'La prioridad seleccionada no es válida';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Actualizar el evento
        UPDATE EVENTO
        SET TITULO = @TITULO, 
            DESCRIPCION = @DESCRIPCION, 
            FECHA_HORA = @FECHA_HORA, 
            ID_PRIORIDAD = @ID_PRIORIDAD
        WHERE ID_EVENTO = @ID_EVENTO;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
GO
--Eliminar eventos y sus relaciones con los pacientes existentes
CREATE OR ALTER PROCEDURE SP_ELIMINAR_EVENTO
    @ID_EVENTO INT,
    @ID_CUIDADOR INT,
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que el evento existe y pertenece al cuidador
        IF NOT EXISTS (SELECT 1 FROM EVENTO WHERE ID_EVENTO = @ID_EVENTO AND ID_USUARIO = @ID_CUIDADOR)
        BEGIN
            SET @ERROR_ID = 1;
            SET @ERROR_DESCRIPTION = 'El evento no existe o no pertenece al cuidador';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Eliminar todas las relaciones en la tabla EVENTO_USUARIO
        DELETE FROM EVENTO_USUARIO 
        WHERE ID_EVENTO = @ID_EVENTO;

        -- Eliminar el evento de la tabla EVENTO
        DELETE FROM EVENTO 
        WHERE ID_EVENTO = @ID_EVENTO;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;

--SP obtener eventos perspectiva de usuario
CREATE OR ALTER PROCEDURE SP_OBTENER_EVENTOS_PACIENTE
    @ID_PACIENTE INT,
	 @ID_RETURN INT OUTPUT,
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        -- Obtener todos los eventos asociados al paciente, sin importar el cuidador
        SELECT 
            E.ID_EVENTO, -- Identificador único del evento
            E.TITULO, -- Título del evento
            E.DESCRIPCION, -- Descripción opcional del evento
            E.FECHA_HORA, -- Fecha y hora programada para el evento
            P.ID_PRIORIDAD, -- Identificador de la prioridad del evento (1: Baja, 2: Media, 3: Alta)
            P.DESCRIPCION AS PRIORIDAD, -- Nombre de la prioridad (Baja, Media, Alta)
            U.ID_USUARIO AS ID_CUIDADOR, -- Identificador del cuidador que creó el evento
            U.NOMBRE AS NOMBRE_CUIDADOR -- Nombre del cuidador que creó el evento
        FROM EVENTO E
        -- Relaciona el evento con la prioridad
        INNER JOIN PRIORIDAD P ON E.ID_PRIORIDAD = P.ID_PRIORIDAD
        -- Relaciona el evento con los pacientes asignados
        INNER JOIN EVENTO_USUARIO EU ON E.ID_EVENTO = EU.ID_EVENTO
        -- Relaciona el evento con el cuidador que lo creó
        INNER JOIN USUARIO U ON E.ID_USUARIO = U.ID_USUARIO
        -- Filtra los eventos asignados al paciente solicitado
        WHERE EU.ID_USUARIO = @ID_PACIENTE;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ID_RETURN = -1;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;

--SP obtener eventos perspectiva cuidador
CREATE OR ALTER PROCEDURE SP_OBTENER_EVENTOS_CUIDADOR
    @ID_CUIDADOR INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Obtener los eventos del cuidador con la lista de pacientes en formato JSON
    SELECT 
        E.ID_EVENTO,
        E.TITULO,
        E.DESCRIPCION,
        E.FECHA_HORA,
        P.ID_PRIORIDAD,
        P.DESCRIPCION AS PRIORIDAD,
        (
            SELECT U.ID_USUARIO AS ID, U.NOMBRE AS NOMBRE
            FROM EVENTO_USUARIO EU
            INNER JOIN USUARIO U ON EU.ID_USUARIO = U.ID_USUARIO
            WHERE EU.ID_EVENTO = E.ID_EVENTO
            FOR JSON PATH
        ) AS PACIENTES
    FROM EVENTO E
    INNER JOIN PRIORIDAD P ON E.ID_PRIORIDAD = P.ID_PRIORIDAD
    WHERE E.ID_USUARIO = @ID_CUIDADOR;
END;
GO

-- Procedimiento para enviar un mensaje a un paciente
CREATE OR ALTER PROCEDURE SP_ENVIAR_MENSAJE
    @ID_CUIDADOR INT,
    @ID_PACIENTE INT,
    @CONTENIDO VARCHAR(255),
    @ID_RETURN INT OUTPUT,
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que el usuario que envía el mensaje es un cuidador
        IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE ID_USUARIO = @ID_CUIDADOR AND ID_TIPO_USUARIO = 2)
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 1;
            SET @ERROR_DESCRIPTION = 'El usuario no es un cuidador o no existe';
            ROLLBACK TRANSACTION;
            RETURN;
        END
    
        -- Validar que el paciente existe
        IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE ID_USUARIO = @ID_PACIENTE AND ID_TIPO_USUARIO = 1)
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 2;
            SET @ERROR_DESCRIPTION = 'El paciente no existe';
            ROLLBACK TRANSACTION;
            RETURN;
        END

		IF NOT EXISTS (SELECT 1 FROM CUIDADOR_PACIENTE WHERE ID_USUARIO_CUIDADOR = @ID_CUIDADOR AND ID_USUARIO_PACIENTE = @ID_PACIENTE)
		BEGIN
			SET @ID_RETURN = -1;
            SET @ERROR_ID = 2;
            SET @ERROR_DESCRIPTION = 'NO SE ENCONTRÓ RELACION CON EL CLIENTE';
            ROLLBACK TRANSACTION;
            RETURN;
		END

        -- Insertar mensaje
        INSERT INTO MENSAJE (CONTENIDO, FECHA_ENVIADO, FECHA_RECIBIDO, ID_USUARIO_CUIDADOR, ID_USUARIO_PACIENTE, ID_ESTADO) 
        VALUES (@CONTENIDO, GETDATE(), NULL, @ID_CUIDADOR, @ID_PACIENTE, 1)

        SET @ID_RETURN = SCOPE_IDENTITY(); -- Obtener el ID del mensaje generado

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ID_RETURN = -1;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
GO

-- Procedimiento para obtener los mensajes de un paciente y actualizar su estado si no han sido recibidos
CREATE OR ALTER PROCEDURE SP_OBTENER_MENSAJES_PACIENTE
    @ID_PACIENTE INT,
	@ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Actualizar el estado de los mensajes no recibidos (ID_ESTADO = 1 → 2)
        UPDATE MENSAJE
        SET ID_ESTADO = 2, FECHA_RECIBIDO = GETDATE()
        WHERE ID_USUARIO_PACIENTE = @ID_PACIENTE AND ID_ESTADO = 1;

        -- Obtener todos los mensajes asignados al paciente
        SELECT 
            M.ID_MENSAJE,
            M.CONTENIDO,
            M.FECHA_ENVIADO,
            M.ID_USUARIO_CUIDADOR AS ID_CUIDADOR,
            U.NOMBRE AS NOMBRE_CUIDADOR,
            M.ID_ESTADO
        FROM MENSAJE M
        INNER JOIN USUARIO U ON M.ID_USUARIO_CUIDADOR = U.ID_USUARIO
        WHERE M.ID_USUARIO_PACIENTE = @ID_PACIENTE;

        -- Si todo salió bien, confirmar los cambios
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
        ROLLBACK TRANSACTION;
    END CATCH
END;
GO

-- Procedimiento para actualizar el estado de los mensajes como 'vistos'
CREATE OR ALTER PROCEDURE SP_ACTUALIZAR_ESTADO_MENSAJES
    @ID_PACIENTE INT,
	@ID_MENSAJE INT,
	@ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;
		
		IF NOT EXISTS ( SELECT 1 FROM USUARIO WHERE @ID_PACIENTE = ID_USUARIO AND ID_TIPO_USUARIO = 1)
		BEGIN
            SET @ERROR_ID = 1;
            SET @ERROR_DESCRIPTION = 'El usuario no es un PACIENTE o no existe';
            ROLLBACK TRANSACTION;
            RETURN;
		END
		
		IF NOT EXISTS ( SELECT 1 FROM MENSAJE WHERE @ID_MENSAJE = ID_MENSAJE AND @ID_PACIENTE = ID_USUARIO_PACIENTE)
		BEGIN
		    SET @ERROR_ID = 1;
            SET @ERROR_DESCRIPTION = 'NO EXISTE EL MENSAJE O NO PERTENECE AL PACIENTE';
            ROLLBACK TRANSACTION;
            RETURN;
		END

        -- Actualizar el estado del mensaje a leído y registrar la hora de recepción
        UPDATE MENSAJE
        SET ID_ESTADO = 3
        WHERE ID_USUARIO_PACIENTE = @ID_PACIENTE AND ID_ESTADO = 2 AND @ID_MENSAJE = ID_MENSAJE

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
    END CATCH
END;
GO


--SP para crear un juego
CREATE OR ALTER PROCEDURE SP_CREAR_JUEGO
    @ID_CUIDADOR INT,
    @NOMBRE VARCHAR(255),
    @ID_RETURN INT OUTPUT,
    @ERROR_ID INT OUTPUT,
    @ERROR_DESCRIPTION NVARCHAR(MAX) OUTPUT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar que el usuario sea un cuidador
        IF NOT EXISTS (SELECT 1 FROM USUARIO WHERE ID_USUARIO = @ID_CUIDADOR AND ID_TIPO_USUARIO = 2)
        BEGIN
            SET @ID_RETURN = -1;
            SET @ERROR_ID = 1;
            SET @ERROR_DESCRIPTION = 'El usuario no es un cuidador o no existe';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Insertar el juego
        INSERT INTO JUEGO (NOMBRE, ID_USUARIO_CREADOR)
        VALUES (@NOMBRE, @ID_CUIDADOR);

        SET @ID_RETURN = SCOPE_IDENTITY(); -- Obtener el ID del juego creado

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @ID_RETURN = -1;
        SET @ERROR_ID = ERROR_NUMBER();
        SET @ERROR_DESCRIPTION = ERROR_MESSAGE();
    END CATCH
END;
